library(h3) #crazycapivara/h3-r
library(sf)
library(tigris)
options(tigris_use_cache = TRUE)
library(dplyr)

us <-
  tigris::states(year = 2020) |>
  filter(!NAME %in% c(
    "United States Virgin Islands",
    "Guam", "Commonwealth of the Northern Mariana Islands",
    "American Samoa", "Puerto Rico",
    "Alaska", "Hawaii"
  )) |>
  st_union() |>
  st_transform(5072)

# generate a lot of h3 resolution 3 cells that will cover the US and then
# subset to only those needed to cover US
us_h3_3 <-
  geo_to_h3(c(38.5, -98.5), 3) |>
  k_ring(radius = 24) |>
  h3_to_geo_boundary_sf() |>
  st_transform(5072) |>
  st_intersection(us)

## get h3 children for resolution 7
us_h3_7 <-
  purrr::map(us_h3_3$h3_index, h3_to_children, res = 7) |>
  unlist() |>
  unique()

saveRDS(us_h3_7, "data/us_h3_7.rds")

readRDS("data/us_h3_7.rds") |>
  length()

us_h3_7_geo <-
  us_h3_7 |>
  h3_to_geo_boundary_sf()

saveRDS(us_h3_7_geo, "data/us_h3_7_geo.rds")
