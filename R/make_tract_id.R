library(dplyr)
library(s2)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(s2) |>
  mutate(s2_geography = as_s2_geography(s2_cell_to_lnglat(s2))) |>
  distinct(s2, .keep_all = TRUE)

states <-
  tigris::states(year = 2019) |>
  select(GEOID) |>
  mutate(s2_geography = as_s2_geography(geometry)) |>
  tibble::as_tibble() |>
  select(-geometry)

d$state <- states[s2_closest_feature(d$s2_geography, states$s2_geography), "GEOID", drop = TRUE]

message("found ", scales::number(length(unique(d$s2)), big.mark = ","), " unique locations across ", length(unique(d$state)), " states")

s2_tracts <- function(state,  year = 2019) {
  tigris::tracts(state = state, year = year, progress_bar = FALSE, keep_zipped_shapefile = TRUE) |>
    mutate(s2_geography = as_s2_geography(geometry)) |>
    tibble::as_tibble() |>
    select(-geometry)
}

d <- d |>
  nest_by(state) |>
  ungroup() |>
  mutate(state_tracts = purrr::map(state, s2_tracts, .progress = "(down)loading census tracts for each state")) |>
  mutate(census_tract_id_2010 =
           purrr::map2(
             data, state_tracts,
             \(d, st) st[s2_closest_feature(d$s2_geography, st$s2_geography), "GEOID", drop = TRUE],
             .progress = "intersecting census tracts for each state"
           ))

d |>
  select(data, census_tract_id_2010) |>
  tidyr::unnest(cols = c(data, census_tract_id_2010)) |>
  select(-s2_geography) |>
  arrow::write_parquet("data/tract.parquet")
