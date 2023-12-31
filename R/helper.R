#' return the s2 shape of the 2020 contiguous united states
#' @return s2_geography object
#' @export
#' @examples
#' contiguous_us()
contiguous_us <- function() {
  tigris::states(year = 2020) |>
    dplyr::filter(!NAME %in% c(
      "United States Virgin Islands",
      "Guam", "Commonwealth of the Northern Mariana Islands",
      "American Samoa", "Puerto Rico",
      "Alaska", "Hawaii"
    )) |>
    sf::st_as_s2() |>
    s2::s2_union_agg()
}


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
