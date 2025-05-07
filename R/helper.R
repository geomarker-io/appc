.onLoad <- function(...) {
  dir.create(tools::R_user_dir("appc", "data"), recursive = TRUE, showWarnings = FALSE)
  options(
    timeout = max(2500, getOption("timeout")),
    download.file.method = "libcurl"
  )
}

utils::globalVariables(c(
  "s2", "NAME",
  "Sample Duration", "Observation Percent",
  "State Code", "County Code", "Site Num",
  "Latitude", "Longitude", "Arithmetic Mean", "Date Local",
  "lon", "lat", "conc",
  "DUSMASS25", "OCSMASS", "BCSMASS", "SSSMASS25",
  "SO4SMASS", "merra_dust", "merra_oc", "merra_oc",
  "merra_bc", "merra_ss", "merra_so4", "value",
  "d", "pollutant code", "site longitude", "site latitude", "total_emissions",
  "air.2m", "hpbl", "acpcp", "rhum.2m",
  "vis", "pres.sfc", "uwnd.10m", "vwnd.10m",
  "frac_imperv",
  "merra_pm25",
  "plume_smoke", ".rowid",
  "predictions", "variance.estimates",
  "precipitation", "solar_radiation", "specific_humidity",
  "temperature_max", "temperature_min", "wind_direction", "wind_speed"
))

#' Get the closest years to a vector of dates
#'
#' The time between a date and year is calculated using July 1st of the year.
#' @param x a date vector
#' @param years vector of characters (or numerics) representing years to choose from
#' @return a character vector of the closest year in `years` for each date in `x`
#' @export
#' @examples
#' get_closest_year(x = as.Date(c("2021-05-15", "2022-09-01")), years = c("2020", "2022"))
get_closest_year <- function(x, years = as.character(1800:2400)) {
  years <- rlang::arg_match(years, multiple = TRUE)
  if (!inherits(x, "Date")) stop("x must be a date vector", call. = FALSE)
  year_midpoints <-
    years |>
    as.character() |>
    paste0("-07-01")
  which_year <- sapply(x, \(.) which.min(abs(difftime(., year_midpoints))))
  the_closest_years <-
    years[which_year] |>
    as.character()
  return(the_closest_years)
}

check_s2_dates <- function(s2, dates = NULL) {
  # TODO add date arguments for min and max dates that default to what is below
  if (!inherits(s2, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  if (any(is.na(s2))) stop("s2 must not contain any missing values", call. = FALSE)
  if (!any(s2::s2_cell_level(s2) == 30L)) stop("all s2 cell levels must be 30", call. = FALSE)
  if (!is.null(dates)) {
    if (length(s2) != length(dates)) stop("s2 and dates must be the same length", call. = FALSE)
    if (!inherits(dates, "list")) stop("dates must be a list", call. = FALSE)
    if (!all(sapply(dates, \(.) inherits(., "Date")))) stop("everything in the dates list must be `Date` objects", call. = FALSE)
    if (!all(lapply(dates, min) > as.Date("2016-12-31"))) stop("all dates must be later than 2017-01-01", call. = FALSE)
    if (!all(lapply(dates, max) < as.Date("2025-01-01"))) stop("all dates must be earlier than 2025-01-01", call. = FALSE)
  }
}

#' delete all installed data files in the user's data directory for the `appc` package
#' @return NULL
#' @export
appc_clean_data_directory <- function() {
  fls <- fs::dir_info(tools::R_user_dir("appc", "data"))
  cli::cli_alert_warning("Running this command will delete all {nrow(fls)} file{?s} in {tools::R_user_dir('appc', 'data')}")
  ui_confirm()
  fs::dir_delete(tools::R_user_dir("appc", "data"))
  cli::cli_alert_success("Removed {sum(fls$size)}")
  return(invisible(NULL))
}

ui_confirm <- function() {
  if (!interactive()) {
    cli::cli_alert_warning("User input requested, but session is not interactive.")
    cli::cli_alert_info("Assuming this is okay.")
    return(TRUE)
  }
  ans <- readline("Are you sure (y/n)? ")
  if (!ans %in% c("", "y", "Y")) stop("aborted", call. = FALSE)
  return(invisible(TRUE))
}

install_source_preference <- function() {
  any(
    getOption("appc_install_data_from_source", "") != "",
    Sys.getenv("APPC_INSTALL_DATA_FROM_SOURCE", "") != ""
  )
}

install_released_data <- function(released_data_name, package_version = utils::packageVersion("appc")) {
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), released_data_name)
  dl_url <- glue::glue(
    "https://github.com", "geomarker-io",
    "appc", "releases", "download",
    "v{package_version}",
    released_data_name,
    .sep = "/"
  )
  utils::download.file(dl_url, dest_file, quiet = FALSE, mode = "wb")
}
