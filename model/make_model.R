library(dplyr, warn.conflicts = FALSE)
library(grf)

message("loading training data...")
d_train <-
  readRDS("data/train.rds") |>
  filter(pollutant == "pm25")

pred_names <-
  c("x", "y",
    "doy",
    "year",
    "elevation_median_800", "elevation_sd_800",
    "total_aadt_m_400", "truck_aadt_m_400",
    "nei_point_id2w_1000",
    ## "smoke",
    "air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m")

message("training GRF...")
grf <-
  regression_forest(
    X = select(d_train, all_of(pred_names)),
    Y = d_train$conc,
    seed = 224,
    num.threads = parallel::detectCores(),
    num.trees = 100,
    ## compute.oob.predictions = TRUE,
    honesty = FALSE,
    ## tune.parameters = "all",
    ## tune.num.trees = 50,
    ## tune.num.reps = 100,
    ## tune.num.draws = 1000,
    tune.parameters = "none",
    ## mtry = 17, # default effectively uses ncol(X)
    sample.fraction = 0.5,
    min.node.size = 5,
    alpha = 0.05,
    imbalance.penalty = 0,
    clusters = as.factor(d_train$s2),
    equalize.cluster.weights = FALSE
  )

message("tuning output:")

grf$tuning.output

dir.create("model", showWarnings = FALSE)
saveRDS(grf, "model/rf_pm.rds")

message("saved model/rf_pm.rds (", fs::file_info("model/rf_pm.rds")$size, ")")
message("LOLO MAE: ", round(median(abs(grf$predictions - grf$Y.orig)), 3))
message("LOLO cor: ", round(cor.test(grf$predictions, grf$Y.orig, method = "spearman", exact = FALSE)$estimate, 3))

tibble(importance = round(variable_importance(grf), 3),
       variable = names(select(d_train, all_of(pred_names)))) |>
  arrange(desc(importance)) |>
  knitr::kable()
