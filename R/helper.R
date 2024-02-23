.onLoad <- function(...) {
  dir.create(tools::R_user_dir("appc", "data"), recursive = TRUE, showWarnings=FALSE)
  options(timeout = max(2500, getOption("timeout")),
          download.file.method = "libcurl")
}

#' Get the geography of the 2020 contiguous United States
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
  if (!inherits(s2, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  if (any(is.na(s2))) stop("s2 must not contain any missing values", call. = FALSE)
  if (!is.null(dates)) {
    if (length(s2) != length(dates)) stop("s2 and dates must be the same length", call. = FALSE)
    if (!inherits(dates, "list")) stop("dates must be a list", call. = FALSE)
    if (!all(sapply(dates, \(.) inherits(., "Date")))) stop("everything in the dates list must be `Date` objects")
  }
}
