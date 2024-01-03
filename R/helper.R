#' return the s2 shape of the 2020 contiguous united states
#' @return s2_geography object
#' @export
#' @examples
#' contiguous_us()
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


#' get the closest years to a vector of dates
#' @param date a vector of date objects
#' @param years vector of characters (or numerics) representing years to choose from
#' @return a character vector of the closest year in `years` for each date in `date`
#' @export
#' @examples
#' get_closest_year(as.Date(c("2021-06-30", "2021-07-01")), years = 2021:2022)
get_closest_year <- function(date, years) {
  date_year <- as.numeric(format(date, "%Y"))
  purrr::map_chr(date_year, \(x) as.character(years[which.min(abs(as.numeric(years) - x))]))
}

#' install geomarker data
#' Download, convert, and install all required geomarker data for `appc` predictions from 2016 - 2022. The smoke data depends on census tract data retrieved per state from the census API and is *not* downloaded ahead of time here.
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
