# TODO create function to return column name for tracts and states based on input year and replace ifelse statements in the functions
# create lookup table for the GEOID column based on year (for tracts and states??)

## purrr::map(2013:2022, \(.) {
##   grep("GEOID", names(tigris::tracts("OH", "Hamilton", cb = TRUE, year = .)), fixed = TRUE, value = TRUE)
## }) |>
##   suppressWarnings() |>
##   suppressMessages()

s2_states <- function(year) {
  stopifnot(year %in% c(1990, 2000, 2010:2022))
  geoid_col_name <- ifelse(year == 2010, "GEOID10", "GEOID")
    tigris::states(year = year) |>
    dplyr::select(GEOID = dplyr::all_of(geoid_col_name)) |>
    dplyr::mutate(s2_geography = s2::as_s2_geography(geometry)) |>
    tibble::as_tibble() |>
    dplyr::select(-geometry)
}

s2_tracts <- function(state,  year) {
  stopifnot(year %in% as.character(c(1990, 2000, 2010:2022)))
  tigris::tracts(state = state, year = year, progress_bar = FALSE, keep_zipped_shapefile = TRUE) |>
    dplyr::mutate(s2_geography = s2::as_s2_geography(geometry)) |>
    tibble::as_tibble() |>
    dplyr::select(-geometry)
}

#' returns census tract identifier of *the closest* census tract
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param year a numeric data year passed to tigris to get state and tract boundaries
#' @details `tigris::tracts()` powers this, so set `options(tigris_use_cache = TRUE)`
#' to benefit from its caching
#'
#' TODO add documentation on year
#' according to https://github.com/walkerke/tigris available years for tracts and states are 1990, 2000, 2010 - 2022
get_census_tract_id <- function(x, year) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  x_s2_geography <- s2::as_s2_geography(s2::s2_cell_to_lnglat(unique(x)))
  states <- s2_states(year = year)
  d <- 
    tibble::tibble(s2_geography = x_s2_geography,
                   state = states[s2::s2_closest_feature(x_s2_geography, states$s2_geography), "GEOID", drop = TRUE]) |>
    dplyr::nest_by(state) |>
    dplyr::ungroup()
  message("Found ", scales::number(length(unique(x)), big.mark = ","), " unique locations ",
          "across ", nrow(d), " states")
  geoid_col_name <- ifelse(year == 2010, "GEOID10", "GEOID")
  d <-
    d |>
    dplyr::mutate(state_tracts = purrr::map(state, \(.) s2_tracts(state = ., year = year), .progress = "(down)loading tracts")) |>
    dplyr::mutate(census_tract_id =
                    purrr::map2(
                      data, state_tracts,
                      \(d, st) st[s2::s2_closest_feature(d$s2_geography, st$s2_geography), geoid_col_name, drop = TRUE],
                      .progress = "intersecting tracts"
                    ))
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

library(s2)

d <-
  readRDS("data/aqs.rds") |>
  dplyr::select(s2)

# don't get it twisted
d$census_tract_id_2019 <- get_census_tract_id(d$s2, year = 2019)
d$census_tract_id_2020 <- get_census_tract_id(d$s2, year = 2020)
d$census_tract_id_2010 <- get_census_tract_id(d$s2, year = 2010)

saveRDS(d, "data/tract.rds")
