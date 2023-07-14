library(dplyr)
library(grf)
library(s2)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(pollutant, dates, conc, s2)

# delete dups for now; fix in aqs script
duplicated <-
  d |>
  select(pollutant, s2) |>
  duplicated() |>
  which()
d <- slice(d, -duplicated)

d_narr <-
  arrow::read_parquet("data/narr.parquet") |>
  select(s2, pollutant, air.2m, hpbl, acpcp, rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m) |>
  distinct(s2, pollutant, .keep_all = TRUE) # temporarily to remove duplicates will be fixed in aqs script

d <- left_join(d, d_narr, by = c("s2", "pollutant"))

d_nlcd <-
  arrow::read_parquet("data/nlcd.parquet") |>
  select(pollutant, s2, pct_treecanopy, pct_imperviousness) |>
  distinct(s2, pollutant, .keep_all = TRUE)

d <- left_join(d, d_nlcd, by = c("s2", "pollutant"))

d <- d |>
  mutate(pct_treecanopy = round(purrr::map_dbl(pct_treecanopy, 11)), # e.g., 2021
         pct_imperviousness = round(purrr::map_dbl(pct_imperviousness, 4))) # e.g., 2019

d_5072_coords <-
  d |>
  mutate(
    lat = as.matrix(s2_cell_to_lnglat(s2))[, "y"],
    lon = as.matrix(s2_cell_to_lnglat(s2))[, "x"]
  ) |>
  terra::vect(crs = "epsg:4326") |>
  terra::project("epsg:5072") |>
  terra::crds()

d$x <- d_5072_coords[ , "x"]
d$y <- d_5072_coords[ , "y"]

# TODO for now...
d_train <-
  d |>
  tidyr::unnest(c(dates, conc, air.2m, hpbl, acpcp, rhum.2m,
                  vis, pres.sfc, uwnd.10m, vwnd.10m)) |>
  filter(pollutant == "pm25") |>
  filter(dates > as.Date("2019-01-01")) |>
  filter(dates < as.Date("2020-01-01"))

## d_train$year <- as.numeric(format(d_train$dates, "%Y"))
d_train$doy <- as.numeric(format(d_train$dates, "%j"))

pred_names <-
  c("x", "y", "doy",
    ## "year",
    "air.2m", "hpbl", "acpcp", "rhum.2m",
    "vis", "pres.sfc", "uwnd.10m", "vwnd.10m",
    "pct_treecanopy", "pct_imperviousness")

grf <-
  regression_forest(
    X = select(d_train, all_of(pred_names)),
    Y = d_train$conc,
    seed = 224,
    num.threads = parallel::detectCores(),
    compute.oob.predictions = TRUE,
    sample.fraction = 0.5,
    num.trees = 2000,
    ## mtry = 14,
    min.node.size = 1, # default 5
    alpha = 0.05,
    imbalance.penalty = 0,
    honesty = FALSE,
    clusters = as.factor(d_train$s2), # 1,912 possible h3 'levels'
    equalize.cluster.weights = FALSE,
    tune.parameters = "none"
  )

var_imp <- variable_importance(grf)
vi <- tibble(var_imp = round(var_imp, 4),
             variable = names(select(d_train, all_of(pred_names))))
knitr::kable(arrange(vi, desc(var_imp)))
median(abs(grf$predictions - grf$Y.orig))

## grf_preds_oob <- predict(grf, estimate.variance = TRUE)

# round all predictions and SEs to 4 significant digits

