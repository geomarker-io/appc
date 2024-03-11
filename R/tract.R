#' Get census tract identifier
#'
#' The identifier of the closest census tract geography (retrieved from the US Census API)
#' for the supplied year are returned for each s2 geohash.
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param year a character data year passed to tigris to get state and tract boundaries
#' @param quiet silence progress messages?
#' @details `tigris::tracts()` powers this, so set `options(tigris_use_cache = TRUE)`
#' to benefit from its caching.
#' According to <https://github.com/walkerke/tigris>, available years for tracts
#' and states are 1990, 2000, 2010 - 2022
#' @references <https://www2.census.gov/geo/pdfs/reference/GARM/Ch10GARM.pdf>
#' @export
#' @examples
#' get_census_tract_id(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), year = "2020")
get_census_tract_id <- function(x, year = as.character(2010:2023), quiet = FALSE) {
  check_s2_dates(x)
  year <- rlang::arg_match(year)
  x_s2_geography <- s2::as_s2_geography(s2::s2_cell_to_lnglat(unique(x)))
  states <- s2_states(year = year)
  d <-
    tibble::tibble(
      s2_geography = x_s2_geography,
      state = states[s2::s2_closest_feature(x_s2_geography, states$s2_geography), "GEOID", drop = TRUE]
    ) |>
    dplyr::nest_by(state) |>
    dplyr::ungroup()
  if (!quiet) {
    cli::cli_alert_info("Found {length(unique(x))} unique location{?s} in {nrow(d)} state{?s}")
  }
  geoid_col_name <- ifelse(year == 2010, "GEOID10", "GEOID")
  d <-
    d |>
    dplyr::mutate(state_tracts = purrr::map(
      state, \(.) s2_tracts(state = ., year = year),
      .progress = ifelse(quiet, FALSE, paste0("(down)loading ", year, " tracts"))
    )) |>
    dplyr::mutate(
      census_tract_id =
        purrr::map2(
          data, state_tracts,
          \(d, st) st[s2::s2_closest_feature(d$s2_geography, st$s2_geography), geoid_col_name, drop = TRUE],
          .progress = ifelse(quiet, FALSE, paste0("intersecting ", year, " tracts"))
        )
    )
  the_tracts <-
    d |>
    dplyr::select(data, census_tract_id) |>
    tidyr::unnest(cols = c(data, census_tract_id)) |>
    dplyr::mutate(s2 = s2::as_s2_cell(s2_geography)) |>
    dplyr::select(-s2_geography) |>
    dplyr::relocate(s2, .before = 0) |>
    tibble::deframe()
  the_tracts[as.character(x)]
}


#' Get states geographic boundaries
#' @param year character data year passed to tigris to get tract boundaries
#' @export
#' @examples
#' s2_states(year = "2020")
s2_states <- function(year = as.character(2010:2023)) {
  year <- rlang::arg_match(year)
  geoid_col_name <- ifelse(year == 2010, "GEOID10", "GEOID")
  tigris::states(year = year, progress_bar = FALSE) |>
    dplyr::select(GEOID = dplyr::all_of(geoid_col_name)) |>
    dplyr::mutate(s2_geography = s2::as_s2_geography(geometry)) |>
    tibble::as_tibble() |>
    dplyr::select(-geometry)
}

#' Get census tract geographic boundaries
#' @param state character string of state number or abbreviation
#' @param year character data year passed to tigris to get tract boundaries
#' @return a tibble of tracts with a s2_geography column
#' @export
#' @examples
#' s2_tracts("OH", "2023")
s2_tracts <- function(state, year = as.character(2010:2023)) {
  year <- rlang::arg_match(year)
  tigris::tracts(state = state, year = year, progress_bar = FALSE, keep_zipped_shapefile = TRUE) |>
    dplyr::mutate(s2_geography = s2::as_s2_geography(geometry)) |>
    tibble::as_tibble() |>
    dplyr::select(-geometry) |>
    suppressWarnings()
}

utils::globalVariables(c("census_tract_id", "s2_geography", "s2", "state", "data", "state_tracts", "geometry"))
