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

spec <- appc:::model_spec()
metadata <- appc:::training_metadata()
train_file_output_path <- appc:::model_artifact_path("training")
appc:::check_new_artifact(train_file_output_path)
dir.create(
  dirname(train_file_output_path),
  recursive = TRUE,
  showWarnings = FALSE
)
model_start_date <- spec$coverage_start
model_end_date <- spec$coverage_end

d_aqs <- map(as.character(2017:2025), get_daily_aqs, pollutant = "pm25")
d_aqs[["2026"]] <-
  install_aqs(
    "2026",
    force_reinstall = getOption("appc.refresh_aqs", TRUE)
  ) |>
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
contiguous_us <- utils::getFromNamespace("contiguous_us", "appc")
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

d_train <- appc:::attach_training_outcome(d_train, d$s2, d$dates, d$pm25)

required_predictors <- spec$predictors

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
attr(d_train, "appc_model_training") <- metadata
saveRDS(d_train, train_file_output_path)
cli::cli_alert_info(
  "saved {fs::file_info(train_file_output_path)$size} to {train_file_output_path}"
)
cli::cli_progress_done()
