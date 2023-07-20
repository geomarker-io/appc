library(dplyr)
library(grf)
library(s2)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(pollutant, dates, conc, s2)

d_narr <-
  arrow::read_parquet("data/narr.parquet") |>
  select(s2, pollutant, air.2m, hpbl, acpcp, rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m)

d <- left_join(d, d_narr, by = c("s2", "pollutant"))

d_nlcd <-
  arrow::read_parquet("data/nlcd.parquet") |>
  select(pollutant, s2, pct_treecanopy, pct_imperviousness)

d <- left_join(d, d_nlcd, by = c("s2", "pollutant"))

d <- d |>
  mutate(pct_treecanopy = round(purrr::map_dbl(pct_treecanopy, 4)), # e.g., 2019
         pct_imperviousness = round(purrr::map_dbl(pct_imperviousness, 1))) # e.g., 2019

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

d_train <-
  d |>
  tidyr::unnest(c(dates, conc, air.2m, hpbl, acpcp, rhum.2m,
                  vis, pres.sfc, uwnd.10m, vwnd.10m)) |>
  filter(pollutant == "pm25")

d_train$year <- as.numeric(format(d_train$dates, "%Y"))
d_train$doy <- as.numeric(format(d_train$dates, "%j"))

d_train <- d_train |> filter(year %in% 2020:2022)

pred_names <-
  c("x", "y", "doy",
    "year",
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
    clusters = as.factor(d_train$s2),
    equalize.cluster.weights = FALSE,
    tune.parameters = "none"
  )

var_imp <- variable_importance(grf)
vi <- tibble(var_imp = round(var_imp, 4),
             variable = names(select(d_train, all_of(pred_names))))
knitr::kable(arrange(vi, desc(var_imp)))
median(abs(grf$predictions - grf$Y.orig))
cor.test(grf$predictions, grf$Y.orig)


## | var_imp|variable           |
## |-------:|:------------------|
## |  0.6186|x                  |
## |  0.1033|hpbl               |
## |  0.0860|doy                |
## |  0.0695|air.2m             |
## |  0.0628|rhum.2m            |
## |  0.0220|vis                |
## |  0.0178|acpcp              |
## |  0.0107|y                  |
## |  0.0061|vwnd.10m           |
## |  0.0009|year               |
## |  0.0009|uwnd.10m           |
## |  0.0005|pct_imperviousness |
## |  0.0004|pres.sfc           |
## |  0.0004|pct_treecanopy     |
## > median(abs(grf$predictions - grf$Y.orig))
## [1] 1.362902
## > cor.test(grf$predictions, grf$Y.orig)

##         Pearson's product-moment correlation

## data:  grf$predictions and grf$Y.orig
## t = 539.18, df = 161287, p-value < 2.2e-16
## alternative hypothesis: true correlation is not equal to 0
## 95 percent confidence interval:
##  0.8002340 0.8037169
## sample estimates:
##       cor 
## 0.8019823 
