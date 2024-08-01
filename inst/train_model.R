library(dplyr, warn.conflicts = FALSE)
library(purrr)
library(grf)

# load development version if developing (instead of currently installed version)
if (file.exists("./inst")) {
  devtools::load_all()
} else {
  library(appc)
}

train_file_output_path <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("training_data_v{packageVersion('appc')}.rds"))
d_train <- readRDS(train_file_output_path)


pred_names <-
  c(
    "x", "y",
    "doy", "year",
    "elevation_median", "elevation_sd",
    "plume_smoke",
    "temperature_max", "temperature_min", "precipitation", "solar_radiation", "wind_speed", "wind_direction", "specific_humidity",
    ## "air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m"
    "hpbl",
    ## "merra_pm25",
    "merra_dust", "merra_oc", "merra_bc", "merra_ss", "merra_so4"
    ## "urban_imperviousness",
    ## "aadt_total_m", "aadt_truck_m",
    ## "nei_point_id2w"
  )

cli::cli_progress_step("training GRF")
grf <-
  regression_forest(
    X = select(d_train, all_of(pred_names)),
    Y = d_train$conc,
    seed = 224,
    num.threads = parallel::detectCores(),
    num.trees = 200,
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
file_output_path <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("rf_pm_v{packageVersion('appc')}.qs"))
qs::qsave(grf, file_output_path, preset = "fast")
cli::cli_alert_info("saved rf_pm.rds ({fs::file_info(file_output_path)$size}) to {file_output_path}")
cli::cli_progress_done()
