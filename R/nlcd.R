#' installs NLCD impervious raster data into user's data directory for the `appc` package
#' @param year a character string that is the year of the data
#' @return path to impervious raster data
install_impervious <- function(year = as.character(c(2019, 2016, 2013, 2011, 2008, 2004, 2001))) {
  year <- rlang::arg_match(year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("nlcd_impervious_{year}.tif"))
  if (file.exists(dest_file)) return(dest_file)
  message(glue::glue("downloading {year} NLCD impervious raster"))
  nlcd_zip_path <- fs::path(tempdir(), glue::glue("nlcd_impervious_{year}.zip"))
  glue::glue("https://s3-us-west-2.amazonaws.com/mrlc/nlcd_{year}_impervious_l48_20210604.zip") |>
    httr::GET(httr::write_disk(nlcd_zip_path), httr::progress(), overwrite = TRUE)
  nlcd_raw_paths <- unzip(nlcd_zip_path, exdir = tempdir())
  message(glue::glue("converting {year} NLCD impervious raster"))
  system2(
    "gdal_translate",
    c("-of COG",
      grep(".img", nlcd_raw_paths, fixed = TRUE, value = TRUE),
      shQuote(dest_file))
  )
  return(dest_file)
}

#' get imperviou summary data
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param year a character string that is the year of the imperviou data
#' @param fun function to summarize extracted data
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return a vector of imperviou values (the same length as `x`)
get_impervious_summary <- function(x, year, fun = mean, buffer = 400) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  impervious_raster <- terra::rast(install_impervious(year = year))
  x_vect <-
    tibble::tibble(
      s2 = unique(x),
      s2_geography = s2::s2_buffer_cells(s2::s2_cell_to_lnglat(s2), distance = buffer)
    ) |>
    sf::st_as_sf() |>
    terra::vect() |>
    terra::project(impervious_raster)
  xx <- terra::extract(impervious_raster, x_vect, fun = fun, ID = FALSE)$Layer_1
  setNames(xx, as.character(x_vect$s2))[as.character(x)]
  }

#' installs NLCD treecanopy raster data into user's data directory for the `appc` package
#' @param year a character string that is the year of the data
#' @return path to treecanopy raster data
install_treecanopy <- function(year = as.character(2021:2011)) {
  year <- rlang::arg_match(year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("nlcd_treecanopy_{year}.tif"))
  if (file.exists(dest_file)) return(dest_file)
  message(glue::glue("downloading {year} NLCD treecanopy raster"))
  nlcd_zip_path <- fs::path(tempdir(), glue::glue("nlcd_treecanopy_{year}.zip"))
  glue::glue("https://s3-us-west-2.amazonaws.com/mrlc/nlcd_tcc_CONUS_{year}_v2021-4.zip") |>
    httr::GET(httr::write_disk(nlcd_zip_path), httr::progress(), overwrite = TRUE)
  nlcd_raw_paths <- unzip(nlcd_zip_path, exdir = tempdir())
  message(glue::glue("converting {year} NLCD treecanopy raster"))
  system2(
    "gdal_translate",
    c("-of COG",
      "-co BIGTIFF=YES",
      grep(".tif$", nlcd_raw_paths, value = TRUE),
      shQuote(dest_file))
  )
  return(dest_file)
}

#' get treecanopy summary data
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param year a character string that is the year of the treecanopy data
#' @param fun function to summarize extracted data
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return a vector of treecanopy values (the same length as `x`)
get_treecanopy_summary <- function(x, year, fun = mean, buffer = 400) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  treecanopy_raster <- terra::rast(install_treecanopy(year = year))
  x_vect <-
    tibble::tibble(
      s2 = unique(x),
      s2_geography = s2::s2_buffer_cells(s2::s2_cell_to_lnglat(s2), distance = buffer)
    ) |>
    sf::st_as_sf() |>
    terra::vect() |>
    terra::project(treecanopy_raster)
  xx <- terra::extract(treecanopy_raster, x_vect, fun = fun, ID = FALSE)$Layer_1
  setNames(xx, as.character(x_vect$s2))[as.character(x)]
  }

library(dplyr, warn.conflicts = FALSE)
## library(s2)
## library(terra)
## library(purrr)

d <- arrow::read_parquet("data/aqs.parquet")
## x = d$s2
## year = "2019"

d$treecanopy_2019 <- get_treecanopy_summary(d$s2, year = "2019")
d$impervious_2019 <- get_impervious_summary(d$s2, year = "2019")

d$treecanopy_2016 <- get_treecanopy_summary(d$s2, year = "2016")
d$treecanopy_2017 <- get_treecanopy_summary(d$s2, year = "2017")
d$treecanopy_2018 <- get_treecanopy_summary(d$s2, year = "2018")
d$treecanopy_2020 <- get_treecanopy_summary(d$s2, year = "2020")
d$treecanopy_2021 <- get_treecanopy_summary(d$s2, year = "2021")
d$impervious_2016 <- get_impervious_summary(d$s2, year = "2016")

arrow::write_parquet(d, "data/nlcd.parquet")

