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
#' and will return zero values.
#' If files are available but no smoke plumes intersect, then a zero values is also returned.
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2017-11-06")),
#'   "8841a45555555555" = as.Date(c("2017-06-22", "2023-08-15", "2024-12-30"))
#' )
#' get_hms_smoke_data(x = s2::as_s2_cell(names(d)), dates = d)
get_hms_smoke_data <- function(x, dates) {
  check_s2_dates(x, dates)
  d_smoke <-
    install_hms_smoke_data() |>
    readRDS()
  date_smoke_geoms <- purrr::map(dates, \(.) d_smoke[as.character(.)])
  withr::with_options(list(sf_use_s2 = FALSE, future.rng.onMisuse = "ignore"), {
    out <-
      purrr::map(
        seq_along(x),
        \(i) {
          purrr::map(
            date_smoke_geoms[[i]],
            \(.) sf::st_join(sf::st_as_sf(s2::s2_cell_to_lnglat(x[[i]])), .)
          ) |>
            suppressMessages() |>
            purrr::map("Density") |>
            purrr::map(
              \(.) as.numeric(factor(., levels = c("Light", "Medium", "Heavy")))
            ) |>
            purrr::map_dbl(sum, na.rm = TRUE) |>
            as.numeric() |>
            suppressWarnings()
        },
        .progress = "intersecting smoke data"
      )
  })
  return(out)
}

#' installs HMS smoke data into user's data directory for the `appc` package
#' @param hms_smoke_start_date a date object that is the first day of hms smoke data installed
#' @param hms_smoke_end_date a date object that is the last day of hms smoke data installed
#' @param force_reinstall logical; download data from original source instead of reusing older downloads
#' @return for `install_hms_smoke_data()`, a character string path to the installed RDS file
#' @rdname get_hms_smoke_data
#' @export
install_hms_smoke_data <- function(
  hms_smoke_start_date = as.Date("2017-01-01"),
  hms_smoke_end_date = as.Date("2025-10-31"),
  force_reinstall = FALSE
) {
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), "hms_smoke.rds")
  if (file.exists(dest_file) & !force_reinstall) {
    return(as.character(dest_file))
  }
  smoke_days <- seq(hms_smoke_start_date, hms_smoke_end_date, by = 1)
  all_smoke_daily_data <-
    purrr::map(
      smoke_days,
      download_daily_smoke_data,
      .progress = glue::glue(
        "downloading HMS smoke data: {hms_smoke_start_date} - {hms_smoke_end_date}"
      )
    ) |>
    purrr::map("result") |>
    stats::setNames(smoke_days)
  saveRDS(all_smoke_daily_data, dest_file)
  return(as.character(dest_file))
}

download_daily_smoke_data <- function(date) {
  safe_st_read <- purrr::safely(
    sf::st_read,
    otherwise = sf::st_sf(sf::st_sfc(crs = sf::st_crs("epsg:4326")))
  )
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
