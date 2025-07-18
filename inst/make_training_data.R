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

# get AQS data
d <-
  tidyr::expand_grid(
    ## pollutant = c("pm25", "ozone", "no2"),
    pollutant = "pm25",
    year = as.character(2017:2024)
  ) |>
  purrr::pmap(get_daily_aqs)

message(
  "latest available AQS PM2.5 measurements: ",
  max(dplyr::bind_rows(d)$date)
)

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
      s2::as_s2_geography(contiguous_us)
    )
  )
cli::cli_progress_done()

d_train <- assemble_predictors(x = d$s2, dates = d$dates)

d_train$conc <- unlist(d$conc)

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
