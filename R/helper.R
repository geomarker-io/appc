.onLoad <- function(...) {
  dir.create(
    tools::R_user_dir("appc", "data"),
    recursive = TRUE,
    showWarnings = FALSE
  )
  options(
    timeout = max(5000, getOption("timeout")),
    download.file.method = "libcurl"
  )
}

utils::globalVariables(c(
  "s2",
  "dates",
  "date",
  ".input_row",
  "AQS_DATA_MART_API_EMAIL",
  "AQS_DATA_MART_API_KEY",
  "dist_to_point",
  "NAME",
  "Sample Duration",
  "Observation Percent",
  "State Code",
  "County Code",
  "Site Num",
  "Latitude",
  "Longitude",
  "Arithmetic Mean",
  "Date Local",
  "lon",
  "lat",
  "conc",
  "DUSMASS25",
  "OCSMASS",
  "BCSMASS",
  "SSSMASS25",
  "SO4SMASS",
  "merra_dust",
  "merra_oc",
  "merra_oc",
  "merra_bc",
  "merra_ss",
  "merra_so4",
  "value",
  "d",
  "pollutant code",
  "site longitude",
  "site latitude",
  "total_emissions",
  "air.2m",
  "hpbl",
  "acpcp",
  "rhum.2m",
  "vis",
  "pres.sfc",
  "uwnd.10m",
  "vwnd.10m",
  "frac_imperv",
  "merra_pm25",
  "plume_smoke",
  ".rowid",
  "predictions",
  "variance.estimates",
  "precipitation",
  "solar_radiation",
  "specific_humidity",
  "temperature_max",
  "temperature_min",
  "wind_direction",
  "wind_speed",
  "geom",
  "arithmetic_mean",
  "county_code",
  "date_local",
  "latitude",
  "longitude",
  "observation_percent",
  "sample_duration",
  "site_number",
  "state_code",
  "validity_indicator"
))

check_s2_dates <- function(
  s2,
  dates = NULL,
  check_date_min = model_spec()$coverage_start,
  check_date_max = model_spec()$coverage_end
) {
  if (!inherits(s2, "s2_cell")) {
    stop("x must be a s2_cell vector", call. = FALSE)
  }
  if (length(s2) == 0L) {
    stop("x must contain at least one location", call. = FALSE)
  }
  if (any(is.na(s2))) {
    stop("s2 must not contain any missing values", call. = FALSE)
  }
  if (!all(s2::s2_cell_is_valid(s2)) || !all(s2::s2_cell_level(s2) == 30L)) {
    stop("all s2 cell levels must be 30", call. = FALSE)
  }
  if (!is.null(dates)) {
    if (length(s2) != length(dates)) {
      stop("s2 and dates must be the same length", call. = FALSE)
    }
    if (!inherits(dates, "list")) {
      stop("dates must be a list", call. = FALSE)
    }
    if (!all(sapply(dates, \(.) inherits(., "Date")))) {
      stop("everything in the dates list must be `Date` objects", call. = FALSE)
    }
    if (any(lengths(dates) == 0L) || any(vapply(dates, anyNA, logical(1)))) {
      stop(
        "dates must be nonempty and must not contain missing values",
        call. = FALSE
      )
    }
    if (!is.null(check_date_min)) {
      if (!all(lapply(dates, min) >= as.Date(check_date_min))) {
        stop("all dates must be later than `check_date_min`", call. = FALSE)
      }
    }
    if (!is.null(check_date_max)) {
      if (!all(lapply(dates, max) <= as.Date(check_date_max))) {
        stop("all dates must be earlier than `check_date_max", call. = FALSE)
      }
    }
  }
}

#' delete all installed data files in the user's data directory for the `appc` package
#' @return NULL
#' @export
appc_clean_data_directory <- function() {
  fls <- fs::dir_info(tools::R_user_dir("appc", "data"))
  cli::cli_alert_warning(
    "Running this command will delete all {nrow(fls)} file{?s} in {tools::R_user_dir('appc', 'data')}"
  )
  ui_confirm()
  fs::dir_delete(tools::R_user_dir("appc", "data"))
  cli::cli_alert_success("Removed {sum(fls$size)}")
  return(invisible(NULL))
}

ui_confirm <- function() {
  if (!interactive()) {
    cli::cli_alert_warning(
      "User input requested, but session is not interactive."
    )
    cli::cli_alert_info("Assuming this is okay.")
    return(TRUE)
  }
  ans <- readline("Are you sure (y/n)? ")
  if (!ans %in% c("", "y", "Y")) {
    stop("aborted", call. = FALSE)
  }
  return(invisible(TRUE))
}
