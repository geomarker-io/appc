#' Get daily North American Regional Reanalysis (NARR) weather data
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a list of date vectors for the NARR data, must be the same length as `x`
#' @param narr_var a character string that is the name of a NARR variable
#' @param narr_year a character string that is the year for the NARR data
#' @details NARR data comes as 0.3 degrees gridded data, which is about 32 sq km resolution. s2 geohashes
#' are intersected with this 0.3 degree grid for matching with daily weather values.
#' @return for `get_narr_data()`, a list of numeric vectors of NARR values (the same length as `x` and `dates`)
#' @references <https://psl.noaa.gov/data/gridded/data.narr.html>
#' @references <https://www.ncei.noaa.gov/products/weather-climate-models/north-american-regional>
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
#' )
#' get_narr_data(x = s2::as_s2_cell(names(d)), dates = d, narr_var = "air.2m")
get_narr_data <- function(
  x,
  dates,
  narr_var = c(
    "air.2m",
    "hpbl",
    "acpcp",
    "rhum.2m",
    "vis",
    "pres.sfc",
    "uwnd.10m",
    "vwnd.10m"
  )
) {
  check_s2_dates(x, dates, check_date_min = "1979-01-01", check_date_max = NULL)
  narr_var <- rlang::arg_match(narr_var)
  narr_raster <-
    dates |>
    unlist() |>
    as.Date(origin = "1970-01-01") |>
    unique() |>
    format("%Y") |>
    unique() |>
    purrr::map_chr(
      \(.) install_narr_data(narr_var = narr_var, narr_year = .)
    ) |>
    purrr::map(terra::rast) |>
    purrr::reduce(c)
  names(narr_raster) <- as.Date(terra::time(narr_raster))
  x_vect <-
    s2::s2_cell_to_lnglat(x) |>
    as.data.frame() |>
    terra::vect(geom = c("x", "y"), crs = "+proj=longlat +datum=WGS84") |>
    terra::project(narr_raster)
  narr_cells <- terra::cells(narr_raster[[1]], x_vect)[, "cell"]
  xx <- as.data.frame(t(terra::extract(narr_raster, narr_cells)))
  purrr::map2(1:ncol(xx), dates, \(.x, .y) xx[as.character(.y), .x]) |>
    stats::setNames(as.character(x))
}

#' Installs NARR raster data into user's data directory for the `appc` package
#' @param force_reinstall logical; download data from original source instead of reusing older downloads
#' @return for `install_narr_data()`, a character string path to NARR raster data
#' @export
#' @rdname get_narr_data
install_narr_data <- function(
  narr_var = c(
    "air.2m",
    "hpbl",
    "acpcp",
    "rhum.2m",
    "vis",
    "pres.sfc",
    "uwnd.10m",
    "vwnd.10m"
  ),
  narr_year = as.character(2016:2024),
  force_reinstall = FALSE
) {
  narr_var <- rlang::arg_match(narr_var)
  narr_year <- rlang::arg_match(narr_year)
  dest_file <- fs::path(
    tools::R_user_dir("appc", "data"),
    glue::glue("narr_{narr_var}_{narr_year}.nc")
  )
  if (file.exists(dest_file) & !force_reinstall) return(dest_file)
  message(glue::glue("downloading {narr_year} {narr_var}:"))
  glue::glue(
    "https://downloads.psl.noaa.gov",
    "Datasets",
    "NARR",
    "Dailies",
    "monolevel",
    "{narr_var}.{narr_year}.nc",
    .sep = "/"
  ) |>
    utils::download.file(destfile = dest_file, mode = "wb")
  return(dest_file)
}
