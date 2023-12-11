library(dplyr, warn.conflicts = FALSE)
library(grf)

d_train <-
  arrow::read_parquet("data/train.parquet") |>
  filter(pollutant == "pm25", year == 2022)

pred_names <-
  c("x", "y", "doy",
    ## "year",
    "nei_pm25_id2w",
    "air.2m", "hpbl", "acpcp", "rhum.2m",
    "vis", "pres.sfc", "uwnd.10m", "vwnd.10m",
    "pct_treecanopy", "pct_imperviousness",
    "elevation", "elevation_sd")

grf <-
  regression_forest(
    X = select(d_train, all_of(pred_names)),
    Y = d_train$conc,
    seed = 224,
    num.threads = parallel::detectCores(),
    compute.oob.predictions = TRUE,
    sample.fraction = 0.5,
    num.trees = 1000,
    ## mtry = 14,
    min.node.size = 5, # 1?
    alpha = 0.05,
    imbalance.penalty = 0,
    honesty = FALSE,
    clusters = as.factor(d_train$s2),
    equalize.cluster.weights = FALSE,
    tune.parameters = "none"
  )

dir.create("model", showWarnings = FALSE)
saveRDS(grf, "model/rf_pm.rds")

message("LOLO MAE: ", round(median(abs(grf$predictions - grf$Y.orig)), 3))
message("LOLO cor: ", round(cor.test(grf$predictions, grf$Y.orig)$estimate, 3))

message("variable importance:")
tibble(var_imp = round(variable_importance(grf), 3),
       variable = names(select(d_train, all_of(pred_names)))) |>
  arrange(desc(var_imp)) |>
  knitr::kable()
