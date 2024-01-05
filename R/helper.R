#' Get the geography of the 2020 contiguous United States
#' @return s2_geography object
#' @export
#' @examples
#' \dontrun{
#' contiguous_us()
#' }
contiguous_us <- function() {
  tigris::states(year = 2020, progress_bar = FALSE) |>
    dplyr::filter(!NAME %in% c(
      "United States Virgin Islands",
      "Guam", "Commonwealth of the Northern Mariana Islands",
      "American Samoa", "Puerto Rico",
      "Alaska", "Hawaii"
    )) |>
    sf::st_as_s2() |>
    s2::s2_union_agg()
}

utils::globalVariables("NAME")


#' Get the closest years to a vector of dates
#' @param date a vector of date objects
#' @param years vector of characters (or numerics) representing years to choose from
#' @return a character vector of the closest year in `years` for each date in `date`
#' @export
#' @details To find the closest year, each date is converted to a year
#' and the differences with the provided years is minimzed. This is a problem....
#' @examples
#' \dontrun{
#' get_closest_year(as.Date(c("2021-09-15", "2022-09-01")), years = c(2020, 2022))
#' }
get_closest_year <- function(date, years) {
  date_year <- as.numeric(format(date, "%Y"))
  purrr::map_chr(date_year, \(x) as.character(years[which.min(abs(as.numeric(years) - x))]))
}

#' Install (almost) all of the geomarker data
#' 
#' Download, convert, and install all required geomarker data for `appc` predictions from 2016 - 2022.
#' The smoke data depends on census tract data retrieved per state from the census API and is *not* downloaded ahead of time here.
#' @return a character vector of the paths to installed geomarker data
#' @export
install_geomarker_data <- function() {
  c(
    install_elevation_data(),
    tidyr::expand_grid(narr_var = c("air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m"),
                       narr_year = as.character(2016:2022)) |>
      purrr::pmap_chr(install_narr_data),
    purrr::map_chr(c("2017", "2020"), install_nei_point_data),
    purrr::map_chr(c("2016", "2019"), install_impervious),
    purrr::map_chr(as.character(2016:2021), install_treecanopy),
    install_smoke_pm_data()
  ) |>
    invisible()
}
