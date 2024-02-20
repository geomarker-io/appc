#' Get average buffered urban imperviousness
#'
#' The percent urban imperviousness of each NLCD 30 x 30 m cell within `buffer` meters of
#' locations in `x` are averaged. 
#' @param x a vector of s2 cell identifiers (`s2_cell` object)
#' @param year a character string that is the year of the urban imperviousness data
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return for `get_urban_imperviousness()`, a numeric vector the same length as `x`
#' @references <https://www.mrlc.gov/data/type/urban-imperviousness>
#' @references <https://www.mrlc.gov/viewer/>
#' @references <https://www.usgs.gov/centers/eros/science/national-land-cover-database>
#' @details Urban imperviousness data is released sequentially, so the 2021 data is retrieved
#' from the 2023-06-30 release; both the 2019 and 2016 data are retrieved from the 2021-06-04 release.
#' From the [metadata](https://www.mrlc.gov/downloads/sciweb1/shared/mrlc/metadata/nlcd_2021_impervious_l48_20230630.xml) 
#' attribute definition for percent imperviousness: "while the file structure shows values in range from 0-255,
#' the values of 0-100 are the only real populated values, in addition to a background value of 127". Extracted values
#' greater than 100 are changed to 0 before averaging.
#' @export
#' @examples
#' get_urban_imperviousness(
#'   x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
#'   year = "2021"
#' )
get_urban_imperviousness <- function(x, year, buffer = 400) {
  check_s2_dates(x)
  the_raster <-
    install_urban_imperviousness(year = year) |>
    terra::rast()
  x_vect <-
    tibble::tibble(
      s2 = unique(x),
      s2_geography = s2::s2_cell_to_lnglat(s2)
    ) |>
    sf::st_as_sf() |>
    terra::vect() |>
    terra::project(terra::crs(the_raster)) |>
    terra::buffer(buffer)
  my_mean <- function(x) {
    backgrounds <- which(x > 100)
    x[backgrounds] <- 0
    mean(x, na.rm = TRUE)
  }
  xx <- terra::extract(the_raster, x_vect, fun = my_mean, ID = FALSE)$Layer_1
  stats::setNames(xx, as.character(x_vect$s2))[as.character(x)]
}

#' `install_urban_imperviousness()` installs NLCD urban imperviousness raster data into user's data directory for the `appc` package
#' @param year a character string that is the year of the urban imperviousness data
#' @return for `install_impervious()`, a character string path to impervious raster data
#' @rdname get_urban_imperviousness
#' @export
install_urban_imperviousness <- function(year = as.character(c(2021, 2019, 2016))) {
  year <- rlang::arg_match(year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("urban_imperviousness_{year}.tif"))
  if (file.exists(dest_file)) return(dest_file)
  if (!install_source_preference()) {
    install_released_data(released_data_name = glue::glue("urban_imperviousness_{year}.tif"))
    return(as.character(dest_file))
  }
  message(glue::glue("downloading {year} NLCD impervious raster"))
  nlcd_zip_path <- fs::path(tempdir(), glue::glue("nlcd_impervious_{year}.zip"))
  dplyr::case_when(
    year == "2021" ~ "https://s3-us-west-2.amazonaws.com/mrlc/nlcd_2021_impervious_l48_20230630.zip",
    year == "2019" ~ "https://s3-us-west-2.amazonaws.com/mrlc/nlcd_2019_impervious_l48_20210604.zip",
    year == "2016" ~ "https://s3-us-west-2.amazonaws.com/mrlc/nlcd_2016_impervious_l48_20210604.zip"
  ) |>
    utils::download.file(nlcd_zip_path, mode = "wb")
  nlcd_raw_paths <- utils::unzip(nlcd_zip_path, exdir = tempdir())
  message(glue::glue("converting {year} NLCD impervious raster"))
  system2(
    "gdal_translate",
    c("-of GTiff",
      "-co COMPRESS=DEFLATE",
      grep(".img", nlcd_raw_paths, fixed = TRUE, value = TRUE),
      shQuote(dest_file))
  )
  return(dest_file)
}

