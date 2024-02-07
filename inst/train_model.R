library(dplyr, warn.conflicts = FALSE)
library(grf)
# load development version if developing (instead of currently installed version)
if (file.exists("./inst/make_training_data.R")) {
  devtools::load_all()
} else {
  library(appc)
}

message("loading training data...")
message(fs::path(fs::path_package("appc"), "training_data.rds"))
d_train <-
  readRDS(fs::path(fs::path_package("appc"), "training_data.rds")) |>
  filter(pollutant == "pm25")

pred_names <-
  c(
    "x", "y",
    "doy", "year", "month",
    "elevation_median_800", "elevation_sd_800",
    "aadt_total_m_400", "aadt_truck_m_400",
    "air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m",
    "impervious_400", "treecanopy_400",
    ## "merra_pm25",
    "merra_dust", "merra_oc", "merra_bc", "merra_ss", "merra_so4",
    "nei_point_id2w_1000",
    "smoke_pm"
  )

message("training GRF...")
grf <-
  regression_forest(
    X = select(d_train, all_of(pred_names)),
    Y = d_train$conc,
    seed = 224,
    num.threads = parallel::detectCores(),
    num.trees = 100,
    compute.oob.predictions = TRUE,
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

message("saving GRF...")
file_output_path <- fs::path(fs::path_package("appc"), "rf_pm.rds")
saveRDS(grf, file_output_path)
message("saved rf_pm.rds (", fs::file_info(file_output_path)$size, ") to ", file_output_path)

message("LLOOB estimates:")
message("MAE = ", round(median(abs(grf$predictions - grf$Y.orig)), 3))
message("Cor = ", round(cor.test(grf$predictions, grf$Y.orig, method = "spearman", exact = FALSE)$estimate, 3))

message("tuning output:")
grf$tuning.output

tibble(
  importance = round(variable_importance(grf), 3),
  variable = names(select(d_train, all_of(pred_names)))
) |>
  arrange(desc(importance)) |>
  knitr::kable()
