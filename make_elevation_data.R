library(dplyr)
library(s2)
library(terra)

# TODO automate download from https://prism.oregonstate.edu/normals/
elevation_raster <- rast("./PRISM_us_dem_800m_bil/PRISM_us_dem_800m_bil.bil")

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(s2) |>
  mutate(s2_geography = as_s2_geography(s2_cell_to_lnglat(s2)))

d_vect <-
  d |>
  mutate(s2_geography = s2_buffer_cells(s2_geography, distance = 800)) |>
  sf::st_as_sf() |>
  vect() |>
  terra::project(elevation_raster)

# average and sd of elevation within 400 m buffer radius circle
d$elevation <-
  terra::extract(elevation_raster, d_vect, fun = median, ID = FALSE) |>
  pull(PRISM_us_dem_800m_bil)

d$elevation_sd <-
  terra::extract(elevation_raster, d_vect, fun = sd, ID = FALSE) |>
  pull(PRISM_us_dem_800m_bil)

d |>
  select(-s2_geography) |>
  arrow::write_parquet("data/elevation.parquet")
