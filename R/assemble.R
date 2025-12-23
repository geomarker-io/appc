#' Assemble a tibble of required predictors for the exposure assessment model
#'
#' @param x a vector of s2 cell identifers (`s2_cell` object); currently required to be within the contiguous united states
#' @param dates a list of date vectors for the predictions, must be the same length as `x`
#' @param pollutant ignored now, but reserved for future sets of predictors specific to different pollutants
#' @return a tibble with one row for each unique s2 location - date combination where columns
#' are predictors required for the exposure assessment model
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15", "2023-09-30"))
#' )
#' assemble_predictors(x = s2::as_s2_cell(names(d)), dates = d) |>
#'   tibble::glimpse()
assemble_predictors <- function(x, dates, pollutant = c("pm25")) {
  check_s2_dates(x, dates)
  d <- tibble::tibble(s2 = x, dates = dates)
  cli::cli_progress_step("checking that s2 are within the contiguous US")
  contig_us_flag <- s2::s2_intersects(
    s2::s2_cell_center(d$s2),
    s2::as_s2_geography(contiguous_us)
  )
  if (!all(contig_us_flag)) {
    stop(
      "not all s2 locations are within the contiguous united states",
      call. = FALSE
    )
  }

  cli::cli_progress_step("adding coordinates")
  conus_coords <-
    sf::st_as_sf(s2::s2_cell_center(d$s2)) |>
    sf::st_transform(sf::st_crs(5072)) |>
    sf::st_coordinates() |>
    tibble::as_tibble()
  d$x <- conus_coords$X
  d$y <- conus_coords$Y

  cli::cli_progress_step("adding elevation")
  d$elevation_median <- get_elevation_summary(
    x = d$s2,
    fun = stats::median,
    buffer = 1200
  )
  d$elevation_sd <- get_elevation_summary(
    x = d$s2,
    fun = stats::sd,
    buffer = 1200
  )
  ## cli::cli_progress_step("adding AADT using level 14 s2 approximation (~ 260 m sq)")
  ## d$traffic <- get_traffic_summary(d$s2, buffer = 1500, s2_approx_level = "14")
  ## d$aadt_total_m <- purrr::map_dbl(d$traffic, "aadt_total_m")
  ## d$aadt_truck_m <- purrr::map_dbl(d$traffic, "aadt_truck_m")
  ## d$traffic <- NULL

  cli::cli_progress_step("adding HMS smoke data")
  d$plume_smoke <- get_hms_smoke_data(x = d$s2, dates = d$dates)

  cli::cli_progress_step("adding NARR")
  d$hpbl <- get_narr_data("hpbl", x = d$s2, dates = d$dates)

  cli::cli_progress_step("adding gridMET")
  my_gridmet <- purrr::partial(get_gridmet_data, x = d$s2, dates = d$dates)
  d$temperature_max <- my_gridmet("tmmx")
  d$temperature_min <- my_gridmet("tmmn")
  d$precipitation <- my_gridmet("pr")
  d$solar_radiation <- my_gridmet("srad")
  d$wind_speed <- my_gridmet("vs")
  d$wind_direction <- my_gridmet("th")
  d$specific_humidity <- my_gridmet("sph")

  ## cli::cli_progress_step("adding NLCD")
  ## d$frac_imperv <- get_nlcd_frac_imperv(d$s2, d$dates, fun = stats::median, buffer = 1200)

  cli::cli_progress_step("adding MERRA")
  d$merra <- get_merra_data(d$s2, d$dates)
  d$merra_dust <- purrr::map(d$merra, "merra_dust")
  d$merra_oc <- purrr::map(d$merra, "merra_oc")
  d$merra_bc <- purrr::map(d$merra, "merra_bc")
  d$merra_ss <- purrr::map(d$merra, "merra_ss")
  d$merra_so4 <- purrr::map(d$merra, "merra_so4")
  d$merra_pm25 <- purrr::map(d$merra, "merra_pm25")
  d$merra <- NULL

  ## cli::cli_progress_step("adding NEI")
  ## nei_years <- c("2017", "2020")
  ## d$nei_point_id2w <-
  ##   purrr::map(nei_years, \(x) get_nei_point_summary(d$s2, year = x, pollutant_code = "PM25-PRI", buffer = 2500)) |>
  ##   stats::setNames(nei_years) |>
  ##   purrr::list_transpose()
  ## d$nei_point_id2w <- purrr::map2(d$dates, d$nei_point_id2w, \(x, y) y[get_closest_year(x = x, years = names(y[1]))])

  cli::cli_progress_step("adding time components")
  d <-
    d |>
    tidyr::unnest(
      cols = c(
        dates,
        hpbl,
        temperature_max,
        temperature_min,
        precipitation,
        solar_radiation,
        wind_speed,
        wind_direction,
        specific_humidity,
        ## air.2m, acpcp, rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m,
        ## frac_imperv,
        merra_pm25,
        merra_dust,
        merra_oc,
        merra_bc,
        merra_ss,
        merra_so4,
        ## urban_imperviousness,
        ## nei_point_id2w,
        plume_smoke
      )
    ) |>
    dplyr::rename(date = dates)
  d$year <- as.numeric(format(d$date, "%Y"))
  d$doy <- as.numeric(format(d$date, "%j"))
  cli::cli_progress_done()

  return(d)
}
