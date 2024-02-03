#' Get average buffered National Land Cover Database (NLCD) values
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param product get the "impervious" or "treecanopy" summary?
#' @param year a character string that is the year of the impervious or treecanopy data;
#' note that each product has different available years
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return for `get_nlcd_summary()`, a vector of mean impervious or treecanopy values (the same length as `x`)
#' @references <https://www.usgs.gov/centers/eros/science/national-land-cover-database>
#' @references <https://www.mrlc.gov/>
#' @export
#' @examples
#' \dontrun{
#' get_nlcd_summary(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
#'                  "impervious", year = "2019")
#' get_nlcd_summary(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
#'                 "treecanopy", year = "2019")
#' }
get_nlcd_summary <- function(x, product = c("impervious", "treecanopy"), year, buffer = 400) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  product <- rlang::arg_match(product)
  the_raster <-
    glue::glue("install_{product}(year = '{year}')") |>
    rlang::parse_expr() |>
    eval() |>
    terra::rast()
  x_vect <-
    tibble::tibble(
      s2 = unique(x),
      s2_geography = s2::s2_cell_to_lnglat(s2)
    ) |>
    sf::st_as_sf() |>
    terra::vect() |>
    terra::project(the_raster) |>
    terra::buffer(buffer)
  xx <- terra::extract(the_raster, x_vect, fun = mean, ID = FALSE)$Layer_1
  stats::setNames(xx, as.character(x_vect$s2))[as.character(x)]
}

#' `install_impervious()` installs NLCD impervious raster data into user's data directory for the `appc` package
#' @param year a character string that is the year of the NLCD data
#' @return for `install_impervious()`, a character string path to impervious raster data
#' @rdname get_nlcd_summary
#' @export
install_impervious <- function(year = as.character(c(2019, 2016, 2013, 2011, 2008, 2004, 2001))) {
  year <- rlang::arg_match(year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("nlcd_impervious_{year}.tif"))
  if (file.exists(dest_file)) return(dest_file)
  message(glue::glue("downloading {year} NLCD impervious raster"))
  nlcd_zip_path <- fs::path(tempdir(), glue::glue("nlcd_impervious_{year}.zip"))
  glue::glue("https://s3-us-west-2.amazonaws.com/mrlc/nlcd_{year}_impervious_l48_20210604.zip") |>
    utils::download.file(nlcd_zip_path)
  nlcd_raw_paths <- utils::unzip(nlcd_zip_path, exdir = tempdir())
  message(glue::glue("converting {year} NLCD impervious raster"))
  system2(
    "gdal_translate",
    c("-of COG",
      grep(".img", nlcd_raw_paths, fixed = TRUE, value = TRUE),
      shQuote(dest_file))
  )
  return(dest_file)
}

#' `install_treecanopy()` installs NLCD treecanopy raster data into user's data directory for the `appc` package
#' @param year a character string that is the year of the NLCD data
#' @return for `install_treecanopy()`, a character string path to treecanopy raster data
#' @rdname get_nlcd_summary
#' @export
install_treecanopy <- function(year = as.character(2021:2011)) {
  year <- rlang::arg_match(year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("nlcd_treecanopy_{year}.tif"))
  if (file.exists(dest_file)) return(dest_file)
  message(glue::glue("downloading {year} NLCD treecanopy raster"))
  nlcd_zip_path <- fs::path(tempdir(), glue::glue("nlcd_treecanopy_{year}.zip"))
  glue::glue("https://s3-us-west-2.amazonaws.com/mrlc/nlcd_tcc_CONUS_{year}_v2021-4.zip") |>
    httr::GET(httr::write_disk(nlcd_zip_path), httr::progress(), overwrite = TRUE)
  nlcd_raw_paths <- utils::unzip(nlcd_zip_path, exdir = tempdir())
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

