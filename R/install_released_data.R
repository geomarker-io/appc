#' Download pre-installed data from GitHub release
#' 
#' `install_smoke_pm_data()`, `install_merra_data()`,
#' `install_traffic()`, and install_nei_point_data()`
#' all download and then transform or subset data into
#' smaller files to be used by appc `get_*_data()` functions.
#' Because this installation process can take a long time, the installed
#' geomarker data are (by default) downloaded from the
#' corresponding github release.
#'
#' To turn *off* the default usage of downloading
#' pre-generated data and to instead install data
#' geomarker data directly from their sources, set
#' options("appc_install_data_from_source"), or the
#' environment variable `APPC_INSTALL_DATA_FROM_SOURCE`
#' to any non-empty value.
#' @keywords internal
install_released_data <- function(released_data_name, package_version = packageVersion("appc")) {
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), released_data_name)
  glue::glue("https://github.com", "geomarker-io",
             "appc", "releases", "download",
             "v{package_version}",
             released_data_name,
             .sep = "/"
             ) |>
    httr2::request() |>
    httr2::req_progress() |>
    httr2::req_perform(path = dest_file)
}

#' install_source_preference()
#' @keywords internal
install_source_preference <- function() {
  any(
    getOption("appc_install_data_from_source", "") != "",
    Sys.getenv("APPC_INSTALL_DATA_FROM_SOURCE", "") != ""
  )
}
