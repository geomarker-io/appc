library(dplyr, warn.conflicts = FALSE)
library(purrr)
library(grf)

train_file_output_path <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("training_data_v{packageVersion('appc')}.rds"))
d_train <- readRDS(train_file_output_path)

## # load development version if developing (instead of currently installed version)
## if (file.exists("./inst")) {
##   devtools::load_all()
## } else {
##   library(appc)
## }

pred_names <-
  c(
    "x", "y",
    "doy", "year", "month", "dow",
    "elevation_median", "elevation_sd",
    "aadt_total_m", "aadt_truck_m",
    "air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m",
    "urban_imperviousness",
    "merra_pm25",
    "nei_point_id2w",
    "plume_smoke"
  )

cli::cli_progress_step("training GRF")
grf <-
  regression_forest(
    X = select(d_train, all_of(pred_names)),
    Y = d_train$conc,
    seed = 224,
    num.threads = parallel::detectCores(),
    num.trees = 500,
    compute.oob.predictions = TRUE,
    honesty = FALSE,
    tune.parameters = "none",
    sample.fraction = 0.5,
    min.node.size = 5,
    alpha = 0.05,
    imbalance.penalty = 0,
    clusters = as.factor(d_train$s2),
    equalize.cluster.weights = FALSE
  )

cli::cli_progress_step("saving GRF")
file_output_path <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("rf_pm_v{packageVersion('appc')}.rds"))
saveRDS(grf, file_output_path)
cli::cli_alert_info("saved rf_pm.rds ({fs::file_info(file_output_path)$size}) to {file_output_path}")

cli::cli_alert_info("LOLO estimates (MAE and Cor):")
round(median(abs(grf$predictions - grf$Y.orig)), 3)
round(cor.test(grf$predictions, grf$Y.orig, method = "spearman", exact = FALSE)$estimate, 3)

cli::cli_alert_info("variable importance:")
tibble(
  importance = round(variable_importance(grf), 3),
  variable = names(select(d_train, all_of(pred_names)))
) |>
  arrange(desc(importance)) |>
  knitr::kable()
