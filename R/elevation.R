#' Get elevation summary data
#'
#' The `fun` (e.g. `median()` or `sd()`) of the elevations (captured at a spatial resolution of 800 by 800 m) within
#' the buffer distance of each s2 geohash.
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param fun function to summarize extracted data
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return for `get_elevation_summary()`, a numeric vector of elevation summaries, the same length as `x`
#' @export
#' @references <https://prism.oregonstate.edu/normals/>
#' @examples
#' \dontrun{
#' get_elevation_summary(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")))
#' }
get_elevation_summary <- function(x, fun = stats::median, buffer = 800) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  elevation_raster <- terra::rast(install_elevation_data())
  x_vect <-
    tibble::tibble(
      s2 = unique(x),
      s2_geography = s2::s2_buffer_cells(s2::s2_cell_to_lnglat(s2), distance = buffer)
    ) |>
    sf::st_as_sf() |>
    terra::vect() |>
    terra::project(elevation_raster)
  elevations <-
    terra::extract(elevation_raster, x_vect, fun = fun)$PRISM_us_dem_800m_bil |>
    as.list() |>
    stats::setNames(x_vect$s2)
  elevations[as.character(x)] |>
    as.numeric()
}

#' installs elevation data into user's data directory for the `appc` package
#' @return for `install_elevation_data()`, a character string path to elevation raster
#' @rdname get_elevation_summary
#' @export
install_elevation_data <- function() {
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), "PRISM_us_dem_800m_bil.bil")
  if (fs::file_exists(dest_file)) return(dest_file)
  elevation_zip <- tempfile("elevation", fileext = ".zip")
  utils::download.file("https://prism.oregonstate.edu/downloads/data/PRISM_us_dem_800m_bil.zip",
    destfile = elevation_zip
  )
  utils::unzip(elevation_zip, exdir = tools::R_user_dir("appc", "data"))
  return(dest_file)
}
