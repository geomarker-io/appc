#' Get smoke plume data from the NOAA's Hazard Mapping System
#'
#' The HMS operates daily in near real-time by outlining the smoke polygon of each distinct smoke plume
#' and classifying it as "light", "medium", and "heavy". Since multiple plumes of varying or the same classification
#' can cover one another, the total smoke plume exposure is estimated as the weighted sum of all plumes, where
#' "light" = 1, "medium" = 2, and "heavy" = 3.
#' @param x a vector of s2 cell identifers (`s2_cell` object); currently required to be within the contiguous united states
#' @param dates a list of date vectors for the predictions, must be the same length as `x`
#' @param quiet silence progress messages?
#' @return a list of numeric vectors of smoke plume scores (the same length as `x` and `dates`)
#' @references <https://www.ospo.noaa.gov/Products/land/hms.html#about>
#' @details In rare cases, daily files are missing (e.g., "2017-06-22")
#' and will return missing values.  If no smoke plumes intersect, then a zero is returned.
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2017-11-06")),
#'   "8841a45555555555" = as.Date(c("2017-06-22", "2023-08-15"))
#' )
#' get_smoke_data(x = s2::as_s2_cell(names(d)), dates = d)
get_smoke_data <- function(x, dates, quiet = TRUE) {
  check_s2_dates(x, dates)
  mappp::mappp(seq_along(x), \(.i) {
    purrr::map_dbl(
      dates[[.i]],
      \(.) get_daily_smoke(x[[.i]], .)
    )
  },
  parallel = TRUE
  ## .progress = ifelse(quiet, FALSE, "getting smoke plume data")
  )
}

#' get daily smoke data for a vector of s2 locations
#' @examples
#' get_daily_smoke(
#'   x = s2::as_s2_cell(c("8841b39a7c46e25f", "8841a45555555555")),
#'   date = as.Date("2023-08-15")
#' )
#' get_daily_smoke(
#'   x = s2::as_s2_cell(c("8841b39a7c46e25f", "8841a45555555555")),
#'   date = as.Date("2017-06-23")
#' )
get_daily_smoke <- function(x, date) {
  safe_st_read <- purrr::safely(sf::st_read, otherwise = NULL)
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
  if (is.null(smoke_shapefile$result)) {
    return(rep(NA, times = length(x)))
  } else {
    smoke_shapefile <- smoke_shapefile$result
  }
  x_points <-
    x |>
    s2::s2_cell_to_lnglat() |>
    sf::st_as_sf() |>
    tibble::rownames_to_column(".row")
  # assign 1, 2, 3 to Light Medium and Heavy in order to summarize
  suppressMessages(sf::sf_use_s2(FALSE))
  intersection_summary <-
    sf::st_join(x_points, smoke_shapefile) |>
    suppressMessages() |>
    sf::st_drop_geometry() |>
    dplyr::mutate(density = as.numeric(factor(Density, levels = c("Light", "Medium", "Heavy")))) |>
    dplyr::summarize(smoke_plume = sum(density, na.rm = TRUE), .by = .row)
  return(intersection_summary$smoke_plume)
}
