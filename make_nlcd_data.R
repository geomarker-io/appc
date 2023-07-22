library(dplyr, warn.conflicts = FALSE)
library(s2)
library(terra)
library(purrr)

options(timeout = 3000)
download_dir <- fs::path_wd("nlcd_downloads")
dir.create(download_dir, showWarnings = FALSE)

# years avail: 2019, 2016, 2013, 2011, 2008, 2006, 2004, 2001
download_impervious <- function(yr = 2019) {
  nlcd_file_path <- fs::path(download_dir, glue::glue("nlcd_impervious_{yr}.tif"))
  if (file.exists(nlcd_file_path)) {
    return(nlcd_file_path)
  }
  withr::with_tempdir({
    download.file(glue::glue("https://s3-us-west-2.amazonaws.com/mrlc/nlcd_{yr}_impervious_l48_20210604.zip"),
      destfile = glue::glue("nlcd_impervious_{yr}.zip")
    )
    unzip(glue::glue("nlcd_impervious_{yr}.zip"))
    system2(
      "gdal_translate",
      c(
        "-of COG",
        glue::glue("nlcd_{yr}_impervious_l48_20210604.img"),
        shQuote(fs::path(download_dir, glue::glue("nlcd_impervious_{yr}.tif")))
      )
    )
  })
  return(nlcd_file_path)
}

# TODO switch to increasing order and change number in model script; see below about year names
impervious_years <- c(2019, 2016)
impervious_raster <-
  map_chr(impervious_years, download_impervious) |>
  rast()
names(impervious_raster) <- impervious_years

# years avail: 2021 - 2011, annually
download_treecanopy <- function(yr = 2019) {
  nlcd_file_path <- fs::path(download_dir, glue::glue("nlcd_treecanopy_{yr}.tif"))
  if (file.exists(nlcd_file_path)) {
    return(nlcd_file_path)
  }
  withr::with_tempdir({
    download.file(glue::glue("https://s3-us-west-2.amazonaws.com/mrlc/nlcd_tcc_CONUS_{yr}_v2021-4.zip"),
      destfile = glue::glue("nlcd_treecanopy_{yr}.zip")
    )
    unzip(glue::glue("nlcd_treecanopy_{yr}.zip"))
    system2(
      "gdal_translate",
      c(
        "-of COG",
        "-co BIGTIFF=YES",
        glue::glue("nlcd_tcc_conus_{yr}_v2021-4.tif"),
        shQuote(fs::path(download_dir, glue::glue("nlcd_treecanopy_{yr}.tif")))
      )
    )
  })
  return(nlcd_file_path)
}

treecanopy_years <- 2016:2021
treecanopy_raster <-
  map_chr(treecanopy_years, download_treecanopy) |>
  rast()
names(treecanopy_raster) <- treecanopy_years

# read input data
d <-
  arrow::read_parquet("data/aqs.parquet") |>
  mutate(s2_geometry = as_s2_geography(s2_cell_to_lnglat(s2)))

# create 400 m buffers and convert to terra object
d_vect <-
  d |>
  mutate(s2_geometry = s2_buffer_cells(s2_geometry, distance = 400)) |>
  sf::st_as_sf() |>
  terra::vect() |>
  terra::project(treecanopy_raster)

# extract mean for each location as named vectors,
# where the year corresponds to the NLCD year
xx_tcp <- terra::extract(treecanopy_raster, d_vect, fun = mean, ID = FALSE)
d[["pct_treecanopy"]] <- map(1:nrow(d), \(.row) rlang::set_names(unlist(xx_tcp[.row, ]), names(xx_tcp)))
xx_imp <- terra::extract(impervious_raster, d_vect, fun = mean, ID = FALSE)
d[["pct_imperviousness"]] <- map(1:nrow(d), \(.row) rlang::set_names(unlist(xx_imp[.row, ]), names(xx_imp)))

# TODO names don't make it back in using parquet files; how to specify which years are which here?
d |>
  select(-s2_geometry) |>
  arrow::write_parquet("data/nlcd.parquet")
