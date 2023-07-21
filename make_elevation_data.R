library(dplyr)
library(s2)
library(terra)

# TODO automate download from https://prism.oregonstate.edu/normals/
elevation_raster <- rast("./PRISM_us_dem_800m_bil/PRISM_us_dem_800m_bil.bil")

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(s2)

d_vect <- d |>
  mutate(
    lat = as.matrix(s2_cell_to_lnglat(s2))[, "y"],
    lon = as.matrix(s2_cell_to_lnglat(s2))[, "x"]
  ) |>
  vect(crs = "epsg:4326") |>
  project(elevation_raster)

d$elevation <-
  terra::extract(elevation_raster, d_vect, ID = FALSE) |>
  pull(PRISM_us_dem_800m_bil)

arrow::write_parquet(d, "data/elevation.parquet")
