.onLoad <- function(...) {
  dir.create(tools::R_user_dir("appc", "data"), recursive = TRUE, showWarnings=FALSE)
  options(timeout = max(900, getOption("timeout")),
          download.file.method = "libcurl")
}

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
