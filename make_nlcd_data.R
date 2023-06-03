library(dplyr)
library(s2)
library(s3)

options("s3.download_folder" = fs::path_wd("s3_downloads"))
data_dir <- fs::path_wd("data")

# if needed, make data/nlcd_pct_treecanopy_YYYY.tif
if (!file.exists(fs::path(data_dir, "nlcd_treecanopy_2021.tif"))) {
  withr::with_tempdir({
    s3::s3_get("s3://mrlc/nlcd_tcc_CONUS_2021_v2021-4.zip", public = TRUE, progress = TRUE) |>
      unzip()
    system2(
      "gdal_translate",
      c(
        "-of COG",
        "-co BIGTIFF=YES",
        "nlcd_tcc_conus_2021_v2021-4.tif",
        shQuote(fs::path(data_dir, "nlcd_treecanopy_2021.tif"))
      )
    )
  })
}

treecanopy_raster <- terra::rast(fs::path(data_dir, "nlcd_treecanopy_2021.tif"))

# if needed, make data/nlcd_pct_impervious_YYYY.tif
if (!file.exists(fs::path(data_dir, "nlcd_impervious_2019.tif"))) {
  withr::with_tempdir({
    s3::s3_get("s3://mrlc/nlcd_2019_impervious_l48_20210604.zip", public = TRUE, progress = TRUE) |>
      unzip()
    system2(
      "gdal_translate",
      c(
        "-of COG",
        "nlcd_2019_impervious_l48_20210604.img",
        shQuote(fs::path(data_dir, "nlcd_impervious_2019.tif"))
      )
    )
  })
}

impervious_raster <- terra::rast(fs::path(data_dir, "nlcd_impervious_2019.tif"))
# cloud option!
## impervious_raster <- terra::rast(glue::glue("/vsis3/geomarker/nlcd_cog/nlcd_impervious_2019.tif"))

# read input data
d <-
  arrow::read_parquet("data/aqs.parquet") |>
  mutate(s2_geometry = as_s2_geography(s2_cell_to_lnglat(s2)))

# create 400 m buffers and convert to terra object
d_terra <-
  d |>
  mutate(s2_geometry = s2_buffer_cells(s2_geometry, distance = 400)) |>
  # TODO how to go from s2 to vect without sf?
  sf::st_as_sf() |>
  terra::vect() |>
  terra::project(impervious_raster)

# extract averages
d <- d |>
  mutate(nlcd_pct_impervious = terra::extract(impervious_raster, d_terra, fun = mean, ID = FALSE)$Layer_1,
         nlcd_pct_treecanopy = terra::extract(treecanopy_raster, d_terra, fun = mean, ID = FALSE)$Layer_1)

d <- d |>
  mutate(nlcd_pct_impervious = terra::extract(impervious_raster, d_terra, fun = mean, ID = FALSE)$Layer_1)

d |>
  select(starts_with("nlcd_")) |>
  summary()

library(ggplot2)

ggplot(d, aes(nlcd_pct_impervious)) +
  geom_histogram()

ggplot(d, aes(nlcd_pct_treecanopy)) +
  geom_histogram()

ggplot(d, aes(nlcd_pct_impervious, nlcd_pct_treecanopy)) +
  geom_point()
