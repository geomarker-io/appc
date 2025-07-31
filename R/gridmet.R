#' Get gridMET surface meteorological data
#'
#' Daily, high spatial resolution (~4-km) data comes from the [Climatology Lab](https://www.climatologylab.org/gridmet.html)
#' and is available for the contiguous US from 1979-yesterday.
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a list of date vectors for the NARR data, must be the same length as `x`
#' @param gridmet_var a character string that is the name of a gridMET variable
#' @param gridmet_year a character string that is the year for the gridMET data; see details
#' @details GRIDMET data comes as 1/24th degree gridded data, which is about 4 sq km resolution. s2 geohashes
#' are intersected with this grid for matching with daily weather values.
#'
#' gridMET variables are named:
#' ```
#' gridmet_variable <- c(
#'   temperature_max = "tmmx",
#'   temperature_min = "tmmn",
#'   precipitation = "pr",
#'   solar_radiation = "srad",
#'   wind_speed = "vs",
#'   wind_direction = "th",
#'   relative_humidity_max = "rmax",
#'   relative_humidity_min = "rmin"
#'   specific_humidity = "sph"
#' )
#' ```
#' @return for `get_gridmet_data()`, a list of numeric vectors of gridMET values (the same length as `x` and `dates`)
#' @references <https://www.climatologylab.org/gridmet.html>
#' @references <https://www.northwestknowledge.net/metdata/data/>
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
#' )
#' get_gridmet_data(x = s2::as_s2_cell(names(d)), dates = d, gridmet_var = "tmmx")
#' get_gridmet_data(x = s2::as_s2_cell(names(d)), dates = d, gridmet_var = "pr")
get_gridmet_data <- function(
  x,
  dates,
  gridmet_var = c(
    "tmmx",
    "tmmn",
    "pr",
    "srad",
    "vs",
    "th",
    "rmax",
    "rmin",
    "sph"
  )
) {
  check_s2_dates(x, dates, check_date_min = "1979-01-01", check_date_max = NULL)
  gridmet_var <- rlang::arg_match(gridmet_var)
  gridmet_years <-
    dates |>
    unlist() |>
    as.Date(origin = "1970-01-01") |>
    sort() |>
    unique() |>
    format("%Y") |>
    unique()
  gridmet_raster <-
    gridmet_years |>
    purrr::map_chr(
      \(.) install_gridmet_data(gridmet_var = gridmet_var, gridmet_year = .)
    ) |>
    purrr::map(terra::rast) |>
    purrr::map2(gridmet_years, \(.x, .y) {
      stats::setNames(
        .x,
        seq(
          as.Date(glue::glue("{.y}-01-01")),
          as.Date(glue::glue("{.y}-12-31")),
          by = 1
        )[1:terra::nlyr(.x)]
      )
    }) |>
    purrr::reduce(c)
  x_vect <-
    s2::s2_cell_to_lnglat(x) |>
    as.data.frame() |>
    terra::vect(geom = c("x", "y"), crs = "+proj=longlat +datum=WGS84") |>
    terra::project(gridmet_raster)
  gridmet_cells <- terra::cells(gridmet_raster[[1]], x_vect)[, "cell"]
  xx <- as.data.frame(t(terra::extract(gridmet_raster, gridmet_cells)))
  purrr::map2(1:ncol(xx), dates, \(.x, .y) xx[as.character(.y), .x]) |>
    stats::setNames(as.character(x))
}

#' Installs gridMET raster data into user's data directory for the `appc` package
#' @param force_reinstall logical; download data from original source instead of reusing older downloads
#' @return for `install_gridmet_data()`, a character string path to gridMET raster data
#' @export
#' @rdname get_gridmet_data
install_gridmet_data <- function(
  gridmet_var = c(
    "tmmx",
    "tmmn",
    "pr",
    "srad",
    "vs",
    "th",
    "rmax",
    "rmin",
    "sph"
  ),
  gridmet_year = as.character(1979:format(Sys.Date(), "%Y")),
  force_reinstall = FALSE
) {
  gridmet_var <- rlang::arg_match(gridmet_var)
  gridmet_year <- rlang::arg_match(gridmet_year)
  dest_file <- fs::path(
    tools::R_user_dir("appc", "data"),
    glue::glue("gridmet_{gridmet_var}_{gridmet_year}.nc")
  )
  if (file.exists(dest_file) & !force_reinstall) {
    return(dest_file)
  }
  message(glue::glue("downloading {gridmet_year} {gridmet_var}:"))
  glue::glue(
    # "https://www.northwestknowledge.net/metdata/data/{gridmet_var}_{gridmet_year}.nc"
    "http://thredds.northwestknowledge.net:8080/thredds/fileServer/MET/{gridmet_var}/{gridmet_var}_{gridmet_year}.nc"
  ) |>
    utils::download.file(destfile = dest_file, mode = "wb")
  return(dest_file)
}
