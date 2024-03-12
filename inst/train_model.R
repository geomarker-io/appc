library(dplyr, warn.conflicts = FALSE)
library(purrr)
library(grf)
future::plan("multicore", workers = 6)
cli::cli_alert_info("using `future::plan()`:")
future::plan()

# load development version if developing (instead of currently installed version)
if (file.exists("./inst")) {
  devtools::load_all()
} else {
  library(appc)
}

cli::cli_progress_step("creating training data")

# get AQS data
d <-
  tidyr::expand_grid(
    ## pollutant = c("pm25", "ozone", "no2"),
    pollutant = "pm25",
    year = as.character(2017:2023)
  ) |>
  purrr::pmap(get_daily_aqs)

# structure for pipeline
d <-
  d |>
  purrr::list_rbind() |>
  dplyr::mutate(dplyr::across(c(pollutant), as.factor)) |>
  dplyr::nest_by(s2, pollutant) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    dates = purrr::map(data, "date"),
    conc = purrr::map(data, "conc")
  ) |>
  dplyr::select(-data)

# subset to contiguous US
d <- d |>
  dplyr::filter(
    s2::s2_intersects(
      s2::as_s2_geography(s2::s2_cell_to_lnglat(s2)),
      contiguous_us()
    )
  )

cli::cli_progress_done()
d_train <- assemble_predictors(d$s2, d$dates)

d_train$conc <- unlist(d$conc)

cli::cli_progress_step("saving training data")
train_file_output_path <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("training_data_v{packageVersion('appc')}.rds"))
saveRDS(d_train, train_file_output_path)
cli::cli_alert_info("saved training_data.rds (", fs::file_info(train_file_output_path)$size, ") to ", train_file_output_path)

pred_names <-
  c(
    "x", "y",
    "doy", "year", "month", "dow",
    "elevation_median_800", "elevation_sd_800",
    "aadt_total_m_400", "aadt_truck_m_400",
    "air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m",
    "urban_imperviousness_400",
    "merra_pm25",
    ## "merra_dust", "merra_oc", "merra_bc", "merra_ss", "merra_so4",
    "nei_point_id2w_1000",
    "plume_smoke"
  )

cli::cli_progress_step("training GRF")
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

cli::cli_progress_step("training GRF")
file_output_path <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("rf_pm_v{packageVersion('appc')}.rds"))
saveRDS(grf, file_output_path)
cli::cli_alert_info("saved rf_pm.rds (", fs::file_info(file_output_path)$size, ") to ", file_output_path)

cli::cli_alert_info(c("LLOOB estimates:",
                      "MAE = ", round(median(abs(grf$predictions - grf$Y.orig)), 3),
                      "Cor = ", round(cor.test(grf$predictions, grf$Y.orig, method = "spearman", exact = FALSE)$estimate, 3)))

cli::cli_alert_info("tuning output:")
grf$tuning.output

cli::cli_alert_info("variable importance:")
tibble(
  importance = round(variable_importance(grf), 3),
  variable = names(select(d_train, all_of(pred_names)))
) |>
  arrange(desc(importance)) |>
  knitr::kable()
