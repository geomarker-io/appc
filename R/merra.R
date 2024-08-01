#' Get MERRA-2 aerosol diagnostics data
#'
#' Total and component (Dust, OC, BC, SS, SO4) surface PM2.5 concentrations
#' from the MERRA-2 [M2T1NXAER v5.12.4](https://disc.gsfc.nasa.gov/datasets/M2T1NXAER_5.12.4/summary) product.
#' @details
#' - To install data from source, an [Earthdata account linked with
#' permissions for GES DISC](https://disc.gsfc.nasa.gov/information/documents?title=Data%20Access) is required.
#' The `EARTHDATA_USERNAME` and `EARTHDATA_PASSWORD` must be set. If
#' a `.env` file is present, environment variables will be loaded
#' using the dotenv package.
#' - Installed data are filtered to a
#' [bounding box](http://bboxfinder.com/#24.766785,-126.474609,49.894634,-66.445313)
#' around the contiguous US, averaged to daily values, and
#' converted to micrograms per cubic meter ($ug/m^3$).
#' - Total surface PM2.5 mass is calculated according to
#' the formula in <https://gmao.gsfc.nasa.gov/reanalysis/MERRA-2/FAQ/#Q4>
#' Set a proxy to be used by all httr calls in the merra functions with `httr::set_config(httr::use_proxy( ... ))`; e.g.
#' `httr::set_config(httr::use_proxy("http://bmiproxyp.chmcres.cchmc.org", 80, Sys.getenv("CCHMC_USERNAME"), Sys.getenv("CCHMC_PASSWORD")))`
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a list of date vectors for the MERRA data, must be the same length as `x`
#' @param merra_year a character string that is the year for the merra data
#' @param merra_date a date object that is the date for the merra data
#' @return for `get_merra_data()`, a list of tibbles the same
#' length as `x`, each containing merra data columns (`merra_dust`, `merra_oc`, `merra_bc`,
#' `merra_ss`, `merra_so4`, `merra_pm25`) with one row per date in `dates`
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
#' )
#' get_merra_data(x = s2::as_s2_cell(names(d)), dates = d)
get_merra_data <- function(x, dates) {
  check_s2_dates(x, dates)
  d_merra <-
    dates |>
    unlist() |>
    as.Date(origin = "1970-01-01") |>
    unique() |>
    format("%Y") |>
    unique() |>
    purrr::map_chr(\(.) install_merra_data(merra_year = .)) |>
    purrr::map(readRDS) |>
    purrr::list_rbind() |>
    dplyr::nest_by(s2) |>
    dplyr::ungroup() |>
    dplyr::mutate(s2 = s2::as_s2_cell(s2)) |>
    dplyr::mutate(s2_geography = s2::s2_cell_to_lnglat(s2)) |>
    stats::na.omit() # some s2 failed to convert to lnglat ?

  x_closest_merra <-
    x |>
    s2::s2_cell_to_lnglat() |>
    s2::s2_closest_feature(d_merra$s2_geography)

  x_closest_merra <-
    d_merra[x_closest_merra, "data"] |>
    dplyr::mutate(s2 = x)

  out <-
    purrr::map2(x_closest_merra$data, dates,
      \(xx, dd) {
        tibble::tibble(date = dd) |>
          dplyr::left_join(xx, by = "date") |>
          dplyr::select(-date)
      })
  names(out) <- as.character(x)
  return(out)
}

#' `install_merra_data()` installs MERRA PM2.5 data into
#' user's data directory for the `appc` package
#' @return for `install_merra_data()`, a character string path to the merra data
#' @details this installs merra data created using code from version 0.2.0 of the package;
#' version 0.3.0 of the package did not change merra data code
#' @export
#' @rdname get_merra_data
install_merra_data <- function(merra_year = as.character(2016:2023)) {
  merra_year <- rlang::arg_match(merra_year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"),
    paste0(c("merra", merra_year), collapse = "_"),
    ext = "rds"
  )
  if (fs::file_exists(dest_file)) {
    return(as.character(dest_file))
  }
  if (!install_source_preference()) {
    install_released_data(released_data_name = glue::glue("merra_{merra_year}.rds"), package_version = "0.2.0")
    return(as.character(dest_file))
  }
  date_seq <- seq(as.Date(paste(c(merra_year, "01", "01"), collapse = "-")),
    as.Date(paste(c(merra_year, "12", "31"), collapse = "-")),
    by = 1
  )
  message(glue::glue("downloading and subsetting daily MERRA files for {merra_year}"))
  # takes a long time, so cache intermediate daily downloads and extractions
  rlang::check_installed("mappp", "to cache the processing of daily MERRA files.")
  merra_data <- mappp::mappp(date_seq, create_daily_merra_data, cache = TRUE, cache_name = "merra_cache")
  names(merra_data) <- date_seq
  tibble::enframe(merra_data, name = "date") |>
    dplyr::mutate(date = as.Date(date)) |>
    tidyr::unnest(cols = c(value)) |>
    saveRDS(dest_file)
  return(as.character(dest_file))
}

#' `create_daily_merra_data` downloads and computes MERRA PM2.5 data for a single day
#' @return for `create_daily_merra_data()`, a tibble with columns for s2,
#' date, and concentrations of PM2.5 total, dust, oc, bc, ss, so4
#' @export
#' @rdname get_merra_data
create_daily_merra_data <- function(merra_date) {
  rlang::check_installed("tidync", "to read daily MERRA files.")
  rlang::check_installed("dotenv", "to read Earthdata credentials; see Details.")
  the_date <- as.Date(merra_date)
  if (file.exists(".env")) dotenv::load_dot_env()
  earthdata_secrets <- Sys.getenv(c("EARTHDATA_USERNAME", "EARTHDATA_PASSWORD"), unset = NA)
  if (any(is.na(earthdata_secrets))) stop("EARTHDATA_USERNAME or EARTHDATA_PASSWORD environment variables are unset", call. = FALSE)
  tf <- tempfile(fileext = ".nc4")
  req_url <-
    fs::path("https://goldsmr4.gesdisc.eosdis.nasa.gov/data/MERRA2",
             "M2T1NXAER.5.12.4",
             format(the_date, "%Y"),
             format(the_date, "%m"),
             paste0("MERRA2_400.tavg1_2d_aer_Nx.", format(the_date, "%Y%m%d")),
             ext = "nc4")
  if ((format(the_date, "%Y") == "2020" & format(the_date, "%m") == "09") ||
        (format(the_date, "%Y") == "2021" & format(the_date, "%m") %in% c("06", "07", "08", "09"))) {
    req_url <- gsub("MERRA2_400.", "MERRA2_401.", req_url, fixed = TRUE)
  }
  httr::GET(
    req_url,
    httr::authenticate(user = earthdata_secrets["EARTHDATA_USERNAME"], password = earthdata_secrets["EARTHDATA_PASSWORD"]),
    httr::write_disk(tf)
  )
  out <-
    tidync::tidync(tf) |>
    tidync::hyper_filter(
      lat = lat > 24.7669 & lat < 49.89,
      lon = lon > -126.4746 & lon < -66.4453
    ) |>
    tidync::hyper_tibble(select_var = c("DUSMASS25", "OCSMASS", "BCSMASS", "SSSMASS25", "SO4SMASS")) |>
    dplyr::mutate(dplyr::across(c(DUSMASS25, OCSMASS, BCSMASS, SSSMASS25, SO4SMASS), \(.) . * 1e9)) |>
    dplyr::rename(
      merra_dust = DUSMASS25,
      merra_oc = OCSMASS,
      merra_bc = BCSMASS,
      merra_ss = SSSMASS25,
      merra_so4 = SO4SMASS
    ) |>
    dplyr::mutate(merra_pm25 = merra_dust + merra_oc + merra_bc + merra_ss + (merra_so4 * 132.14 / 96.06)) |>
    dplyr::group_by(lon, lat) |>
    dplyr::summarize(dplyr::across(dplyr::starts_with("merra"), mean), .groups = "drop") |>
    dplyr::mutate(s2 = s2::as_s2_cell(s2::s2_geog_point(lon, lat))) |>
    dplyr::select(-lon, -lat)
  return(out)
}

