library(dplyr)
library(s2)

set.seed(1)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  mutate(s2_geometry = as_s2_geography(s2_cell_to_lnglat(s2)))


## product <- "impervious"
product <- "landcover"
year <- 2019

# COG option:
## nlcd_raster <- terra::rast(glue::glue("/vsis3/geomarker/nlcd_cog/nlcd_{product}_{year}.tif"))

## local option:
nlcd_raster <-
  s3::s3_get(glue::glue("s3://geomarker/nlcd_cog/nlcd_{product}_{year}.tif"),
    download_folder = "data", progress = TRUE
  ) |>
  terra::rast()

# define legends for raster values (and our green codes)
landcover_key <-
  tibble::tribble(
    ~value, ~landcover_class, ~landcover, ~green,
    11, "water", "water", FALSE,
    12, "water", "ice/snow", FALSE,
    21, "developed", "developed open", TRUE,
    22, "developed", "developed low intensity", TRUE,
    23, "developed", "developed medium intensity", FALSE,
    24, "developed", "developed high intensity", FALSE,
    31, "barren", "rock/sand/clay", FALSE,
    41, "forest", "deciduous forest", TRUE,
    42, "forest", "evergreen forest", TRUE,
    43, "forest", "mixed forest", TRUE,
    51, "shrubland", "dwarf scrub", TRUE,
    52, "shrubland", "shrub/scrub", TRUE,
    71, "herbaceous", "grassland", TRUE,
    72, "herbaceous", "sedge", TRUE,
    73, "herbaceous", "lichens", TRUE,
    74, "herbaceous", "moss", TRUE,
    81, "cultivated", "pasture/hay", TRUE,
    82, "cultivated", "cultivated crops", TRUE,
    90, "wetlands", "woody wetlands", TRUE,
    95, "wetlands", "emergent herbaceous wetlands", TRUE
  ) |>
  mutate(across(c(value, landcover_class, landcover), as.factor))

# prepare for terra extract
d_terra_point <-
  d |>
  terra::vect(crs = terra::crs("epsg:4326")) |>
  terra::project(nlcd_raster)

d_point_out <-
  d |>
  mutate(nlcd_value = factor(terra::extract(nlcd_raster, d_terra_point)$Layer_1)) |>
  left_join(landcover_key, by = c("nlcd_value" = "value")) |>
  select(-nlcd_value)

d_terra_poly <-
  d |>
  mutate(s2_geometry = s2_buffer_cells(s2_geometry, distance = 400)) |>
  # TODO how to go from s2 to vect without sf?
  sf::st_as_sf() |>
  terra::vect() |>
  terra::project(nlcd_raster)

## d_poly_out <-

terra::extract(
  x = nlcd_raster,
  y = d_terra_poly[1:10, ],
  fun = "table",
  exact = TRUE,
  ID = FALSE
) |>
  dplyr::rename_with(
    .fn = \(.) gsub("Layer_1", ., replacement = "nlcd", fixed = TRUE),
    .cols = tidyselect::everything()
  )
