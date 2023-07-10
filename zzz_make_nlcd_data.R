library(dplyr)
library(s2)
library(s3)
library(terra)
library(purrr)

options(timeout = 3000)
options("s3.download_folder" = fs::path_wd("s3_downloads"))
download_dir <- fs::path_wd("nlcd_downloads")
dir.create(download_dir, showWarnings = FALSE)

# years avail: 2019, 2016, 2013, 2011, 2008, 2006, 2004, 2001
download_imperviousness <- function(nlcd_year = 2019) {
  nlcd_file_path <- fs::path(download_dir, glue::glue("nlcd_{nlcd_year}_impervious_l48_20210604.img"))
  if (file.exists(nlcd_file_path)) return(nlcd_file_path)
  s3_get(glue::glue("s3://mrlc/nlcd_{nlcd_year}_impervious_l48_20210604.zip"),
         public = TRUE, progress = TRUE) |>
    unzip(exdir = download_dir)
  return(nlcd_file_path)
  rast(nlcd_file_path)
}

download_imperviousness(2019)

# years avail: 2021 - 2011, annually
download_treecanopy <- function(nlcd_year = 2021) {
  nlcd_file_path <- fs::path(download_dir, glue::glue("nlcd_tcc_conus_{nlcd_year}_v2021-4.tif"))
  if (file.exists(nlcd_file_path)) {
    return(nlcd_file_path)
    }
  s3_get(glue::glue("s3://mrlc/nlcd_tcc_CONUS_{nlcd_year}_v2021-4.zip"),
         public = TRUE, progress = TRUE) |>
    unzip(exdir = download_dir)
  return(nlcd_file_path)
}

download_treecanopy(2021)
download_treecanopy(2020)

download_landcover <- function(nlcd_year = 2019) {
  nlcd_file_path <- fs::path(download_dir, glue::glue("nlcd_tcc_conus_{nlcd_year}_v2021-4.tif"))
  if (file.exists(nlcd_file_path)) {
    return(nlcd_file_path)
    }
  s3_get(glue::glue("s3://mrlc/nlcd_{nlcd_year}_land_cover_l48_20210604.zip"),
         public = TRUE, progress = TRUE) |>
    unzip(exdir = download_dir)
  return(nlcd_file_path)
}

# create raster stack for desired years
# create sds for all nlcd products


# cloud option????
## impervious_raster <- terra::rast(glue::glue("/vsis3/geomarker/nlcd_cog/nlcd_impervious_2019.tif"))

# read input data
d <-
  arrow::read_parquet("data/aqs.parquet") |>
  mutate(s2_geometry = as_s2_geography(s2_cell_to_lnglat(s2)))


# create 400 m buffers and convert to terra object
d_vect <-
  d |>
  mutate(s2_geometry = s2_buffer_cells(s2_geometry, distance = 400)) |>
  # TODO how to go from s2 to vect without sf?
  sf::st_as_sf() |>
  terra::vect() |>
  terra::project(impervious_raster)

nlcd_sds

# if a stack, then will return all years?

# extract averages, for each of the available years
d <- d |>
  mutate(nlcd_pct_impervious = terra::extract(impervious_raster, d_vect, fun = mean, ID = FALSE)$Layer_1,
         nlcd_pct_treecanopy = terra::extract(treecanopy_raster, d_vect, fun = mean, ID = FALSE)$Layer_1)
