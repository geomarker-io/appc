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
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
#' )
#' assemble_predictors(x = s2::as_s2_cell(names(d)), dates = d) |>
#'   tibble::glimpse()
assemble_predictors <- function(x, dates, pollutant = c("pm25")) {
  check_s2_dates(x, dates)
  d <- tibble::tibble(s2 = x, dates = dates)
  cli::cli_progress_step("checking that s2 locations are within the contiguous united states")
  contig_us_flag <- s2::s2_intersects(s2::as_s2_geography(s2::s2_cell_to_lnglat(d$s2)), contiguous_us())
  if (!all(contig_us_flag)) stop("not all s2 locations are within the contiguous united states", call. = FALSE)
  cli::cli_progress_step("adding coordinates")
  conus_coords <-
    sf::st_as_sf(s2::s2_cell_to_lnglat(d$s2)) |>
    sf::st_transform(sf::st_crs(5072)) |>
    sf::st_coordinates() |>
    tibble::as_tibble()
  d$x <- conus_coords$X
  d$y <- conus_coords$Y
  cli::cli_progress_step("adding elevation")
  d$elevation_median <- get_elevation_summary(x = d$s2, fun = stats::median, buffer = 1200)
  d$elevation_sd <- get_elevation_summary(x = d$s2, fun = stats::sd, buffer = 1200)
  cli::cli_progress_step("adding AADT using level 14 s2 approximation (~ 260 m sq)")
  d$traffic <- get_traffic_summary(d$s2, buffer = 1500, s2_approx_level = "14")
  d$aadt_total_m <- purrr::map_dbl(d$traffic, "aadt_total_m")
  d$aadt_truck_m <- purrr::map_dbl(d$traffic, "aadt_truck_m")
  d$traffic <- NULL
  cli::cli_progress_step("adding HMS smoke data")
  d$plume_smoke <- get_hms_smoke_data(x = d$s2, dates = d$dates)
  cli::cli_progress_step("adding NARR")
  my_narr <- purrr::partial(get_narr_data, x = d$s2, dates = d$dates)
  d$air.2m <- my_narr("air.2m")
  d$hpbl <- my_narr("hpbl")
  d$acpcp <- my_narr("acpcp")
  d$rhum.2m <- my_narr("rhum.2m")
  d$vis <- my_narr("vis")
  d$pres.sfc <- my_narr("pres.sfc")
  d$uwnd.10m <- my_narr("uwnd.10m")
  d$vwnd.10m <- my_narr("vwnd.10m")

  cli::cli_progress_step("adding MERRA")
  d$merra <- get_merra_data(d$s2, d$dates)
  ## d$merra_dust <- purrr::map(d$merra, "merra_dust")
  ## d$merra_oc <- purrr::map(d$merra, "merra_oc")
  ## d$merra_bc <- purrr::map(d$merra, "merra_bc")
  ## d$merra_ss <- purrr::map(d$merra, "merra_ss")
  ## d$merra_so4 <- purrr::map(d$merra, "merra_so4")
  d$merra_pm25 <- purrr::map(d$merra, "merra_pm25")
  d$merra <- NULL

  cli::cli_progress_step("adding NLCD urban imperviousness")
  impervious_years <- c("2016", "2019", "2021")
  d$urban_imperviousness <-
    purrr::map(impervious_years, \(x) get_urban_imperviousness(d$s2, year = x, buffer = 2500)) |>
    stats::setNames(impervious_years) |>
    purrr::list_transpose()
  d$urban_imperviousness <- purrr::map2(d$dates, d$urban_imperviousness, \(x, y) y[get_closest_year(x = x, years = names(y[1]))])

  cli::cli_progress_step("adding NEI")
  nei_years <- c("2017", "2020")
  d$nei_point_id2w <-
    purrr::map(nei_years, \(x) get_nei_point_summary(d$s2, year = x, pollutant_code = "PM25-PRI", buffer = 2500)) |>
    stats::setNames(nei_years) |>
    purrr::list_transpose()
  d$nei_point_id2w <- purrr::map2(d$dates, d$nei_point_id2w, \(x, y) y[get_closest_year(x = x, years = names(y[1]))])

  cli::cli_progress_step("adding time components")
  d <-
    d |>
    tidyr::unnest(cols = c(
      dates, air.2m, hpbl, acpcp,
      rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m,
      ## merra_dust, merra_oc, merra_bc, merra_ss, merra_so4,
      merra_pm25,
      urban_imperviousness,
      nei_point_id2w, plume_smoke
    )) |>
    dplyr::rename(date = dates)
  d$year <- as.numeric(format(d$date, "%Y"))
  d$doy <- as.numeric(format(d$date, "%j"))
  d$month <- as.numeric(format(d$date, "%m"))
  d$dow <- as.numeric(format(d$date, "%u"))
  cli::cli_progress_done()

  return(d)
}
