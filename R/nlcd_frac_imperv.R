#' Get NLCD Fractional Impervious Surface
#'
#' NLCD data is from v1 of the [Annual NLCD](https://www.mrlc.gov/data/project/annual-nlcd)
#'
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a list of date vectors for the NLCD data, must be the same length as `x`
#' @param fun function to summarize extracted data
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @param nlcd_year a character string that is the year for the NLCD data
#' @return for `get_nlcd_frac_imperv()`, a list of numeric vectors of fractional impervious
#' surface pixel summaries, the same length as `x`;
#' each vector has values for each date in dates, named according to the NLCD product year
#' @references https://www.usgs.gov/centers/eros/science/annual-nlcd-fractional-impervious-surface
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
#' )
#' get_nlcd_frac_imperv(x = s2::as_s2_cell(names(d)), dates = d)
#' get_nlcd_frac_imperv(x = s2::as_s2_cell(names(d)), dates = d, fun = mean, buffer = 1000)
get_nlcd_frac_imperv <- function(x, dates, fun = stats::median, buffer = 400) {
  check_s2_dates(
    x,
    dates,
    check_date_min = "2017-01-01",
    check_date_max = "2024-12-31"
  )
  nlcd_years <-
    purrr::reduce(dates, c) |>
    format("%Y") |>
    unique()
  nlcd_raster <-
    nlcd_years |>
    purrr::map_chr(install_nlcd_frac_imperv_data) |>
    purrr::map(terra::rast) |>
    purrr::reduce(c)

  names(nlcd_raster) <- nlcd_years

  x_vect <-
    tibble::tibble(
      s2 = x,
      s2_geography = s2::s2_buffer_cells(
        s2::s2_cell_to_lnglat(s2),
        distance = buffer
      )
    ) |>
    sf::st_as_sf() |>
    terra::vect() |>
    terra::project(nlcd_raster)

  d_nlcd <- terra::extract(nlcd_raster, x_vect, fun = fun, ID = FALSE)

  out <-
    dates |>
    purrr::map(format, "%Y") |>
    purrr::map2(
      seq_along(x),
      \(.years, .extract_row) d_nlcd[.extract_row, .years, drop = TRUE]
    ) |>
    purrr::map(unlist)

  return(out)
}

#' Installs annual NLCD Fractional Impervious Surface raster data into user's data directory for the `appc` package
#' @return for `install_nlcd_frac_imperv_data()`, a character string path to NLCD raster data
#' @export
#' @rdname get_nlcd_frac_imperv
install_nlcd_frac_imperv_data <- function(nlcd_year = as.character(2025:2017)) {
  nlcd_year <- rlang::arg_match(nlcd_year)
  if (nlcd_year == "2025") {
    nlcd_year <- "2024"
    cli::cli_alert_warning("2025 NLCD not yet available; using 2024")
  }
  dest_path <- fs::path(
    tools::R_user_dir("appc", "data"),
    glue::glue("Annual_NLCD_FctImp_{nlcd_year}_CU_C1V1.tif")
  )
  if (fs::file_exists(dest_path)) {
    return(dest_path)
  }
  dl_url <- glue::glue(
    "https://www.mrlc.gov/downloads/sciweb1/shared/mrlc/data-bundles/Annual_NLCD_FctImp_{nlcd_year}_CU_C1V1.zip"
  )
  tf <- tempfile()
  utils::download.file(dl_url, tf)
  utils::unzip(tf, exdir = fs::path_dir(dest_path))
  return(dest_path)
}
