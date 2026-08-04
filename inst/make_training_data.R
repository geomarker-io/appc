library(dplyr, warn.conflicts = FALSE)
library(purrr)

# load development version if developing (instead of currently installed version)
if (file.exists("./inst")) {
  devtools::load_all()
} else {
  library(appc)
}

message("using appc, version ", packageVersion("appc"))

cli::cli_progress_step("creating AQS training data")

model_start_date <- as.Date("2017-01-01")
model_end_date <- as.Date("2026-06-30")

d_aqs <- map(as.character(2017:2025), get_daily_aqs, pollutant = "pm25")
d_aqs[["2026"]] <-
  install_aqs("2026", force_reinstall = TRUE) |>
  readRDS()

d <-
  bind_rows(d_aqs) |>
  dplyr::select(s2, date, conc) |>
  dplyr::filter(
    date >= model_start_date,
    date <= model_end_date
  )

stopifnot(
  "AQS data do not start on the expected date" = min(d$date) ==
    model_start_date,
  "AQS data do not end on the expected date" = max(d$date) == model_end_date,
  "AQS concentrations contain missing values" = !anyNA(d$conc),
  "AQS data contain duplicate location-days" = !anyDuplicated(
    d[c("s2", "date")]
  )
)

message(
  "latest available AQS PM2.5 measurements: ",
  max(d$date)
)

# structure for pipeline and subset to contiguous US
d <-
  d |>
  nest_by(s2) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    dates = purrr::map(data, "date"),
    pm25 = purrr::map(data, "conc")
  ) |>
  dplyr::select(-data) |>
  dplyr::filter(
    s2::s2_intersects(
      s2::as_s2_geography(s2::s2_cell_to_lnglat(s2)),
      s2::as_s2_geography(contiguous_us)
    )
  )
cli::cli_progress_done()

d_train <- assemble_predictors(x = d$s2, dates = d$dates)

training_concentrations <- unlist(d$pm25)
stopifnot(
  "predictor rows do not align with AQS concentrations" = nrow(d_train) ==
    length(training_concentrations)
)
d_train$conc <- training_concentrations

required_predictors <-
  c(
    "x",
    "y",
    "doy",
    "year",
    "elevation_median",
    "elevation_sd",
    "plume_smoke",
    "temperature_max",
    "temperature_min",
    "precipitation",
    "solar_radiation",
    "wind_speed",
    "wind_direction",
    "specific_humidity",
    "hpbl",
    "merra_dust",
    "merra_oc",
    "merra_bc",
    "merra_ss",
    "merra_so4"
  )

stopifnot(
  "training data do not contain the required predictors" = all(
    required_predictors %in% names(d_train)
  ),
  "training data do not start on the expected date" = min(d_train$date) ==
    model_start_date,
  "training data do not end on the expected date" = max(d_train$date) ==
    model_end_date,
  "training concentrations contain missing values" = !anyNA(d_train$conc)
)

missing_by_date <-
  d_train |>
  dplyr::group_by(date) |>
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(required_predictors),
      \(x) all(is.na(x))
    ),
    .groups = "drop"
  )
stopifnot(
  "a required predictor is entirely missing for at least one date" = !any(
    as.matrix(dplyr::select(missing_by_date, -date))
  )
)

cli::cli_alert_info("AQS observations by year:")
print(table(format(d_train$date, "%Y")))
cli::cli_alert_info("daily AQS observation counts by year:")
d_train |>
  dplyr::count(date) |>
  dplyr::mutate(calendar_year = format(date, "%Y")) |>
  dplyr::summarise(
    days = dplyr::n(),
    minimum = min(n),
    median = stats::median(n),
    maximum = max(n),
    .by = calendar_year
  ) |>
  print()
cli::cli_alert_info("missing values by predictor and year:")
d_train |>
  dplyr::mutate(calendar_year = format(date, "%Y")) |>
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(required_predictors),
      \(x) sum(is.na(x))
    ),
    .by = calendar_year
  ) |>
  tidyr::pivot_longer(
    -calendar_year,
    names_to = "predictor",
    values_to = "missing"
  ) |>
  print(n = Inf)

cli::cli_progress_step("saving training data")
train_file_output_path <- fs::path(
  tools::R_user_dir("appc", "data"),
  glue::glue("training_data_v{packageVersion('appc')$major}.rds")
)
saveRDS(d_train, train_file_output_path)
cli::cli_alert_info(
  "saved {fs::file_info(train_file_output_path)$size} to {train_file_output_path}"
)
cli::cli_progress_done()
