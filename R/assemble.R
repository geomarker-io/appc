#' Assemble a tibble of required predictors for the exposure assessment model
#' 
#' @param x a vector of s2 cell identifers (`s2_cell` object); currently required to be within the contiguous united states
#' @param dates a list of date vectors for the predictions, must be the same length as `x`
#' @param quiet silence progress messages?
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
assemble_predictors <- function(x, dates, pollutant = c("pm25"), quiet = TRUE) {
  if (!quiet) message("checking input s2 locations and dates")
  check_s2_dates(x, dates)
  d <- tibble::tibble(s2 = x, dates = dates)
  if (!quiet) message("checking that s2 locations are within the contiguous united states")
  contig_us_flag <- s2::s2_intersects(s2::as_s2_geography(s2::s2_cell_to_lnglat(d$s2)), contiguous_us())
  if (!all(contig_us_flag)) stop("not all s2 locations are within the contiguous united states", call. = FALSE)
  if (!quiet) message("adding smoke plume data")
  d$plume_smoke <- get_smoke_data(x = d$s2, dates = d$dates, quiet = quiet)
  if (!quiet) message("adding coordinates")
  conus_coords <-
    sf::st_as_sf(s2::s2_cell_to_lnglat(d$s2)) |>
    sf::st_transform(sf::st_crs(5072)) |>
    sf::st_coordinates() |>
    tibble::as_tibble()
  d$x <- conus_coords$X
  d$y <- conus_coords$Y
  if (!quiet) message("adding elevation")
  d$elevation_median_800 <- get_elevation_summary(x = d$s2, fun = stats::median, buffer = 800)
  d$elevation_sd_800 <- get_elevation_summary(x = d$s2, fun = stats::sd, buffer = 800)
  if (!quiet) message("adding AADT using level 14 s2 approximation (~ 260 m sq)")
  d$traffic_400 <- get_traffic_summary(d$s2, buffer = 400, s2_approx_level = "14")
  d$aadt_total_m_400 <- purrr::map_dbl(d$traffic_400, "aadt_total_m")
  d$aadt_truck_m_400 <- purrr::map_dbl(d$traffic_400, "aadt_truck_m")
  d$traffic_400 <- NULL
  if (!quiet) message("adding NARR")
  my_narr <- purrr::partial(get_narr_data, x = d$s2, dates = d$dates)
  d$air.2m <- my_narr("air.2m")
  d$hpbl <- my_narr("hpbl")
  d$acpcp <- my_narr("acpcp")
  d$rhum.2m <- my_narr("rhum.2m")
  d$vis <- my_narr("vis")
  d$pres.sfc <- my_narr("pres.sfc")
  d$uwnd.10m <- my_narr("uwnd.10m")
  d$vwnd.10m <- my_narr("vwnd.10m")

  if (!quiet) message("adding MERRA")
  d$merra <- get_merra_data(d$s2, d$dates)
  d$merra_dust <- purrr::map(d$merra, "merra_dust")
  d$merra_oc <- purrr::map(d$merra, "merra_oc")
  d$merra_bc <- purrr::map(d$merra, "merra_bc")
  d$merra_ss <- purrr::map(d$merra, "merra_ss")
  d$merra_so4 <- purrr::map(d$merra, "merra_so4")
  ## d$merra_pm25 <- purrr::map(d$merra, "merra_pm25")
  d$merra <- NULL

  if (!quiet) message("adding NLCD urban imperviousness...")
  impervious_years <- c("2016", "2019", "2021")
  d$urban_imperviousness_400 <-
    purrr::map(impervious_years, \(x) get_urban_imperviousness(d$s2, year = x, buffer = 400)) |>
    stats::setNames(impervious_years) |>
    purrr::list_transpose()
  d$urban_imperviousness_400 <- purrr::map2(d$dates, d$urban_imperviousness_400, \(x, y) y[get_closest_year(x = x, years = names(y[1]))])

  if (!quiet) message("adding NEI")
  nei_years <- c("2017", "2020")
  d$nei_point_id2w_1000 <-
    purrr::map(nei_years, \(x) get_nei_point_summary(d$s2, year = x, pollutant_code = "PM25-PRI", buffer = 1000, quiet = quiet)) |>
    stats::setNames(nei_years) |>
    purrr::list_transpose()
  d$nei_point_id2w_1000 <- purrr::map2(d$dates, d$nei_point_id2w_1000, \(x, y) y[get_closest_year(x = x, years = names(y[1]))])

  d <-
    d |>
    tidyr::unnest(cols = c(
      dates, air.2m, hpbl, acpcp,
      rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m,
      merra_dust, merra_oc, merra_bc, merra_ss, merra_so4,
      urban_imperviousness_400,
      nei_point_id2w_1000, plume_smoke
    )) |>
    dplyr::rename(date = dates)

  ## if (!quiet) message("adding smoke via census tract")
  ## suppressWarnings(d$census_tract_id_2010 <- get_census_tract_id(d$s2, year = "2010", quiet = quiet))
  ## d_smoke <- readRDS(install_smoke_pm_data())
  ## d <-
  ##   d |>
  ##   dplyr::left_join(d_smoke, by = c("census_tract_id_2010", "date")) |>
  ##   tidyr::replace_na(list(smoke_pm = 0)) |>
  ##   dplyr::select(-census_tract_id_2010)

  if (!quiet) message("adding time components")
  d$year <- as.numeric(format(d$date, "%Y"))
  d$doy <- as.numeric(format(d$date, "%j"))
  d$month <- as.numeric(format(d$date, "%m"))
  d$dow <- as.numeric(format(d$date, "%u"))

  return(d)
}
