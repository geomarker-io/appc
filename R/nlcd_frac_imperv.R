#' Get NLCD Fractional Impervious Surface
#'
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a list of date vectors for the NLCD data, must be the same length as `x`; each date is matched
#' to the closest available year of [Annual NLCD data](https://www.mrlc.gov/data/project/annual-nlcd)
#' @param fun function to summarize extracted data
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return for `get_nlcd_frac_imperv()`, a numeric vector of fractional impervious surface pixel summaries,
#' the same length as `x`
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2022-06-22", "2022-08-15"))
#' )
#' get_nlcd_frac_imperv(x = s2::as_s2_cell(names(d)), dates = d)
get_nlcd_frac_imperv <- function(x, dates, fun = stats::median, buffer = 400) {
  browser()
  check_s2_dates(x, dates)
  nlcd_years <-
    purrr::reduce(dates, c) |>
    format("%Y") |>
    unique()
  nlcd_raster <-
    nlcd_years |>
    purrr::map_chr(install_nlcd_frac_imperv) |>
    purrr::map(terra::rast) |>
    purrr::reduce(c)

  names(nlcd_raster) <- nlcd_years

  x_vect <-
    tibble::tibble(
      s2 = x,
      s2_geography = s2::s2_buffer_cells(s2::s2_cell_to_lnglat(s2), distance = buffer)
    ) |>
    sf::st_as_sf() |>
    terra::vect() |>
    terra::project(nlcd_raster)

  d_nlcd <- terra::extract(nlcd_raster, x_vect, fun = fun, ID = FALSE)
  # use 2023 NLCD data for 2024 dates; emit message?

  d_nlcd

  dates |>
    purrr::map(format, "%Y")
  # TODO ........

  
}

# download and convert annual NLCD Fractional Impervious Surface for CONUS to COG
# https://www.mrlc.gov/data/type/fractional-impervious-surface
install_nlcd_frac_imperv <- function(year = as.character(2023:2017),
                                     install_dir = tools::R_user_dir("appc", "data")) {
  year <- rlang::arg_match(year)
  if (!fs::dir_exists(install_dir)) {
    stop("the directory ", install_dir, " does not exist", call. = FALSE)
  }
  dest_path <- fs::path(install_dir, glue::glue("Annual_NLCD_FctImp_{year}_CU_C1V0.tif"))
  if (fs::file_exists(dest_path)) {
    return(dest_path)
  }
  dl_url <- glue::glue("https://s3-us-west-2.amazonaws.com/mrlc/Annual_NLCD_FctImp_{year}_CU_C1V0.tif")
  dl_tmp <- tempfile(glue::glue("Annual_NLCD_FctImp_{year}_CU_C1V0"), fileext = ".tif")
  withr::local_options(timeout = 3000)
  download.file(dl_url, dl_tmp)
  system2("gdal_translate", c("-of COG", shQuote(dl_tmp), shQuote(dest_path)))
  return(dest_path)
}

install_nlcd_frac_imperv("2023")
