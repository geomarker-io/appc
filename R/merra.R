# MERRA-2
# an Earthdata account that is authorized for the NASA GESDISC DATA ARCHIVE application is required
# see https://disc.gsfc.nasa.gov/information/documents?title=Data%20Access for more information
# M2T1NXAER: 2 dimensional, hourly, time-averaged, single-level, assimilation, aerosol diagnostics v5.12.4
# https://disc.gsfc.nasa.gov/datasets/M2T1NXAER_5.12.4/summary
# filter to contiguous US: http://bboxfinder.com/#24.766785,-126.474609,49.894634,-66.445313
# all mass units are kg/m3; translate to ug/m3 with 1e9 factor
# total surface PM2.5 mass is calculated according to <https://gmao.gsfc.nasa.gov/reanalysis/MERRA-2/FAQ/#Q4>

#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
#' )

#' get_merra_data(x = s2::as_s2_cell(names(d)), dates = d)


get_merra_data <- function(x, dates) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  d_merra <-
    dates |>
    unlist() |>
    as.Date() |>
    unique() |>
    format("%Y") |>
    unique() |>
    purrr::map_chr(\(.) install_merra_data(merra_year = .)) |>
    purrr::map(arrow::read_parquet) |>
    purrr::list_rbind() |>
    dplyr::nest_by(s2) |>
    dplyr::ungroup() |>
    dplyr::pull(data, s2)
  d_merra_s2_geog <-
    d_merra |>
    names() |>
    s2::as_s2_cell() |>
    s2::s2_cell_to_lnglat()
  x_closest_merra <- 
    x |>
    s2::s2_cell_to_lnglat() |>
    s2::s2_closest_feature(d_merra_s2_geog)
  x_closest_merra <-
    d_merra[x_closest_merra] |>
    setNames(x)
  out <-
    purrr::map2(x_closest_merra, dates,
                \(xx, dd) {
                  tibble::tibble(date = dd) |>
                    dplyr::left_join(xx, by = "date") |>
                    dplyr::select(-date)
                },
                .progress = "extracting closest merra data"
                )
  names(out) <- as.character(x)
  return(out)
}

#' Installs MERRA PM2.5 data into user's data directory for the `appc` package
#' @param year a year object that is the year for the merra data
#' @return for `install_merra_data()`, a character string path to the merra data
#' @export
#' @rdname get_merra_data
install_merra_data <- function(merra_year = as.character(2016:2023)) {
  merra_year <- rlang::arg_match(merra_year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"),
                        paste0(c("merra", merra_year), collapse = "_"), ext = "parquet")
  if (fs::file_exists(dest_file)) return(as.character(dest_file))
  date_seq <- seq(as.Date(paste(c(merra_year, "01", "01"), collapse = "-")),
                  as.Date(paste(c(merra_year, "12", "31"), collapse = "-")),
                  by = 1)
  # takes a long time, so cache intermediate daily downloads and extractions
  merra_data <- mappp::mappp(date_seq, create_daily_merra_data, cache = TRUE, cache_name = "merra_cache")
  names(merra_data) <- date_seq
  tibble::enframe(merra_data, name = "date") |>
    dplyr::mutate(date = as.Date(date)) |>
    tidyr::unnest(cols = c(value)) |>
    arrow::write_parquet(dest_file)
  return(dest_file)
}

#' Downloads and computes MERRA PM2.5 data for a single day
#' @param date a date object that is the date for the merra data
#' @return for `get_daily_merra_data()`, a tibble with columns for s2,
#' date, and concentrations of PM2.5 total, dust, oc, bc, ss, so4 
#' @export
#' @rdname get_merra_data
create_daily_merra_data <- function(date) {
  the_date <- as.Date(date)
  if (file.exists(".env")) dotenv::load_dot_env()
  earthdata_secrets <- Sys.getenv(c("EARTHDATA_USERNAME", "EARTHDATA_PASSWORD"), unset = NA)
  if (any(is.na(earthdata_secrets))) stop("EARTHDATA_USERNAME or EARTHDATA_PASSWORD environment variables are unset", call. = FALSE)
  tf <- tempfile(fileext = ".nc4")
  fs::path("https://goldsmr4.gesdisc.eosdis.nasa.gov/data/MERRA2",
    "M2T1NXAER.5.12.4",
    format(the_date, "%Y"),
    format(the_date, "%m"),
    paste0("MERRA2_400.tavg1_2d_aer_Nx.", format(the_date, "%Y%m%d")),
    ext = "nc4"
  ) |>
    httr2::request() |>
    httr2::req_auth_basic(
      username = earthdata_secrets["EARTHDATA_USERNAME"],
      password = earthdata_secrets["EARTHDATA_PASSWORD"]
    ) |>
    ## httr2::req_progress() |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_proxy("http://bmiproxyp.chmcres.cchmc.org",
      port = 80,
      username = Sys.getenv("CCHMC_USERNAME"),
      password = Sys.getenv("CCHMC_PASSWORD")
    ) |>
    httr2::req_perform(path = tf)
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
    dplyr::summarize(dplyr::across(starts_with("merra"), mean), .groups = "drop") |>
    dplyr::mutate(s2 = s2::as_s2_cell(s2::s2_geog_point(lon, lat))) |>
    dplyr::select(-lon, -lat)
  return(out)
}
