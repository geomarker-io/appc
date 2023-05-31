library(dplyr)
library(s2)

set.seed(1)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  mutate(s2_geometry = as_s2_geography(s2_cell_to_lnglat(s2))) |>
  slice_sample(n = 100)

product <- "landcover"
year <- 2019

# COG option:
nlcd_raster <- terra::rast(glue::glue("/vsis3/geomarker/nlcd_cog/nlcd_{product}_{year}.tif"))

## local option:
nlcd_raster <- s3::s3_get(glue::glue("s3://geomarker/nlcd_cog/nlcd_{product}_{year}.tif"),
                          download_folder = "data", progress = TRUE)

# prepare for terra extract
d_terra <-
  d |>
  terra::vect(crs = terra::crs("epsg:4326")) |>
  terra::project(nlcd_raster)

d$nlcd <- terra::extract(nlcd_raster, d_terra)$Layer_1

d$nlcd <- factor(d$nlcd)



landcover_key <-
  c(
    "0" = "unclassified",
    "11" = "water",
    "12" = "ice/snow",
    "21" = "developed open",
    "22" = "developed low intensity",
    "23" = "developed medium intensity",
    "24" = "developed high intensity",
    "31" = "rock/sand/clay",
    "41" = "deciduous forest",
    "42" = "evergreen forest",
    "43" = "mixed forest",
    "51" = "dwarf scrub",
    "52" = "shrub/scrub",
    "71" = "grassland",
    "72" = "sedge",
    "73" = "lichens",
    "74" = "moss",
    "81" = "pasture/hay",
    "82" = "cultivated crops",
    "90" = "woody wetlands",
    "95" = "emergent herbaceous wetlands"
  )

nlcd_values <- landcover_key[as.character(nlcd_values)]
