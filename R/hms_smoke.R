#' Get smoke plume data from the NOAA's Hazard Mapping System
#'
#' The HMS operates daily in near real-time by outlining the smoke polygon of each distinct smoke plume
#' and classifying it as "light", "medium", and "heavy". Since multiple plumes of varying or the same classification
#' can cover one another, the total smoke plume exposure is estimated as the weighted sum of all plumes, where
#' "light" = 1, "medium" = 2, and "heavy" = 3.
#' @param x a vector of s2 cell identifers (`s2_cell` object); currently required to be within the contiguous united states
#' @param dates a list of date vectors for the predictions, must be the same length as `x`
#' @return for `get_hms_smoke_data()`, a list of numeric vectors of smoke plume scores (the same length as `x` and `dates`)
#' @references <https://www.ospo.noaa.gov/Products/land/hms.html#about>
#' @details Daily HMS shapefiles are missing for 7 days within 2017-2023
#' ("2017-04-27", "2017-05-31", "2017-06-01", "2017-06-01" "2017-06-22", "2017-11-12", "2018-12-31")
#' and will return zero values.  If files are available but no smoke plumes intersect, then a zero values is also returned.
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2017-11-06")),
#'   "8841a45555555555" = as.Date(c("2017-06-22", "2023-08-15"))
#' )
#' get_hms_smoke_data(x = s2::as_s2_cell(names(d)), dates = d)
get_hms_smoke_data <- function(x, dates) {
  check_s2_dates(x, dates)
  d_smoke <- readRDS(install_hms_smoke_data())
  date_smoke_geoms <- purrr::map(dates, \(.) d_smoke[as.character(.)])
  withr::with_options(list(sf_use_s2 = FALSE, future.rng.onMisuse = "ignore"), {
    out <-
      purrr::map(seq_along(x), \(i) {
        purrr::map(date_smoke_geoms[[i]], \(.) sf::st_join(sf::st_as_sf(s2::s2_cell_to_lnglat(x[[i]])), .)) |>
          suppressMessages() |>
          purrr::map("Density") |>
          purrr::map(\(.) as.numeric(factor(., levels = c("Light", "Medium", "Heavy")))) |>
          purrr::map_dbl(sum, na.rm = TRUE) |>
          as.numeric() |>
          suppressWarnings()
      }, .progress = "intersecting smoke data")
  })
  return(out)
}

#' installs HMS smoke data into user's data directory for the `appc` package
#' @return for `install_hms_smoke_data()`, a character string path to the installed RDS file
#' @rdname get_hms_smoke_data
#' @details this installs smoke data created using code from version 0.2.0 of the package;
#' version 0.3.0 of the package did not change smoke data code
#' @export
install_hms_smoke_data <- function() {
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), "hms_smoke.rds")
  if (file.exists(dest_file)) {
    return(as.character(dest_file))
  }
  if (!install_source_preference()) {
    install_released_data(released_data_name = "hms_smoke.rds", package_version = "0.2.0")
    return(as.character(dest_file))
  }
  smoke_days <- seq(as.Date("2017-01-01"), as.Date("2023-12-31"), by = 1)
  all_smoke_daily_data <-
    purrr::map(
      smoke_days,
      download_daily_smoke_data,
      .progress = "downloading all smoke data"
    ) |>
    purrr::map("result") |>
    stats::setNames(smoke_days)
  saveRDS(all_smoke_daily_data, dest_file)
  return(as.character(dest_file))
}

download_daily_smoke_data <- function(date) {
  safe_st_read <- purrr::safely(sf::st_read, otherwise = sf::st_sf(sf::st_sfc(crs = sf::st_crs("epsg:4326"))))
  smoke_shapefile <-
    glue::glue(
      "/vsizip//vsicurl",
      "https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS/Smoke_Polygons/Shapefile",
      format(date, "%Y"),
      format(date, "%m"),
      "hms_smoke{format(date, '%Y%m%d')}.zip",
      .sep = "/"
    ) |>
    safe_st_read(quiet = TRUE)
}

