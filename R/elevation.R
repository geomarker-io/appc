#' installs elevation data into user's data directory for the `appc` package
#' @return path to elevation raster
install_elevation_data <- function() {
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), "PRISM_us_dem_800m_bil.bil")
  if (fs::file_exists(dest_file)) return(dest_file)
  elevation_zip <- tempfile("elevation", fileext = ".zip")
  paste0("https://prism.oregonstate.edu/fetchData.php",
         "?type=bil&kind=normals&spatial=800m&elem=dem&temporal=annual") |>
    download.file(destfile = elevation_zip)
  unzip(elevation_zip, exdir = tools::R_user_dir("appc", "data"))
  return(dest_file)
}

#' get elevation summary data
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param fun function to summarize extracted data
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return a numeric vector of elevation summaries, the same length as `x`
get_elevation_summary <- function(x, fun = median, buffer = 800) {
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
    setNames(x_vect$s2)
  elevations[as.character(x)] |>
    as.numeric()
}

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  dplyr::distinct(s2)

d$elevation_median_800 <- get_elevation_summary(x = d$s2, fun = median, buffer = 800)
d$elevation_sd_800 <- get_elevation_summary(x = d$s2, fun = sd, buffer = 800)

arrow::write_parquet(d, "data/elevation.parquet")
