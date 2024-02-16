#' Get daily PM2.5 model predictions
#'
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a list of date vectors for the predictions, must be the same length as `x`
#' @return a list of tibbles the same length as `x`, each containing
#' columns for the predicted (`pm25`) and its standard error (`pm25_se`)
#' with one row per date in `dates`
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
#' )
#' predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)
predict_pm25 <- function(x, dates) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  grf_file <-  fs::path(tools::R_user_dir("appc", "data"), "rf_pm.rds")
  if(!file.exists(grf_file)) install_released_data("rf_pm.rds")
  message("loading random forest model...")
  grf <- readRDS(grf_file)
  required_predictors <- names(grf$X.orig)

  # create all columns required for rf_model
  d <- tibble::tibble(s2 = x, dates = dates)

  # TODO remove these and return as NA?
  d <- d |>
    dplyr::filter(
      s2::s2_intersects(
        s2::as_s2_geography(s2::s2_cell_to_lnglat(s2)),
        contiguous_us()
      )
    )

  message("adding coordinates...")
  d$x <- s2::s2_x(s2::s2_cell_to_lnglat(d$s2))
  d$y <- s2::s2_y(s2::s2_cell_to_lnglat(d$s2))

  message("adding elevation...")
  d$elevation_median_800 <- get_elevation_summary(x = d$s2, fun = stats::median, buffer = 800)
  d$elevation_sd_800 <- get_elevation_summary(x = d$s2, fun = stats::sd, buffer = 800)

  message("adding AADT...")
  d$traffic_400 <- get_traffic_summary(d$s2, buffer = 400)
  d$aadt_total_m_400 <- purrr::map_dbl(d$traffic_400, "aadt_total_m")
  d$aadt_truck_m_400 <- purrr::map_dbl(d$traffic_400, "aadt_truck_m")
  d$traffic_400 <- NULL

  message("adding NARR...")
  my_narr <- purrr::partial(get_narr_data, x = d$s2, dates = d$dates)
  d$air.2m <- my_narr("air.2m")
  d$hpbl <- my_narr("hpbl")
  d$acpcp <- my_narr("acpcp")
  d$rhum.2m <- my_narr("rhum.2m")
  d$vis <- my_narr("vis")
  d$pres.sfc <- my_narr("pres.sfc")
  d$uwnd.10m <- my_narr("uwnd.10m")
  d$vwnd.10m <- my_narr("vwnd.10m")

  message("adding MERRA...")
  d$merra <- get_merra_data(d$s2, d$dates)
  d$merra_dust <- purrr::map(d$merra, "merra_dust")
  d$merra_oc <- purrr::map(d$merra, "merra_oc")
  d$merra_bc <- purrr::map(d$merra, "merra_bc")
  d$merra_ss <- purrr::map(d$merra, "merra_ss")
  d$merra_so4 <- purrr::map(d$merra, "merra_so4")
  ## d$merra_pm25 <- purrr::map(d$merra, "merra_pm25")
  d$merra <- NULL

  message("adding NLCD urban imperviousness...")
  impervious_years <- c("2016", "2019", "2021")
  d$urban_imperviousness_400 <-
    purrr::map(impervious_years, \(x) get_urban_imperviousness(d$s2, year = x, buffer = 400)) |>
    stats::setNames(impervious_years) |>
    purrr::list_transpose()
  d$urban_imperviousness_400 <- purrr::map2(d$dates, d$urban_imperviousness_400, \(x, y) y[get_closest_year(date = x, years = names(y[1]))], .progress = "matching annual impervious")

  message("adding NEI...")
  nei_years <- c("2017", "2020")
  d$nei_point_id2w_1000 <-
    purrr::map(nei_years, \(x) get_nei_point_summary(d$s2, year = x, pollutant_code = "PM25-PRI", buffer = 1000)) |>
    stats::setNames(nei_years) |>
    purrr::list_transpose()
  d$nei_point_id2w_1000 <- purrr::map2(d$dates, d$nei_point_id2w_1000, \(x, y) y[get_closest_year(date = x, years = names(y[1]))], .progress = "matching annual NEI")

  d <-
    d |>
    tidyr::unnest(cols = c(
      dates, air.2m, hpbl, acpcp,
      rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m,
      merra_dust, merra_oc, merra_bc, merra_ss, merra_so4,
      urban_imperviousness_400,
      nei_point_id2w_1000
    )) |>
    dplyr::rename(date = dates)

  message("adding smoke via census tract...")
  suppressWarnings(d$census_tract_id_2010 <- get_census_tract_id(d$s2, year = "2010"))
  d_smoke <- readRDS(install_smoke_pm_data())
  d <-
    d |>
    dplyr::left_join(d_smoke, by = c("census_tract_id_2010", "date")) |>
    tidyr::replace_na(list(smoke_pm = 0)) |>
    dplyr::select(-census_tract_id_2010)

  message("adding time components...")
  d$year <- as.numeric(format(d$date, "%Y"))
  d$doy <- as.numeric(format(d$date, "%j"))
  d$month <- as.numeric(format(d$date, "%m"))


  # check that newdata has required predictors
  stopifnot(all(required_predictors %in% names(d)))
  stopifnot(inherits(grf, "regression_forest")) # grf package will be avail as dependency of appc? or just rlang::is_installed for predicting air pollution?

  # return predictions
  foofy <- grf::regression_forest
  d_pred <-
    stats::predict(grf,
      dplyr::select(d, dplyr::all_of(required_predictors)),
      estimate.variance = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::transmute(
      pm25 = predictions,
      pm25_se = sqrt(variance.estimates)
    )

  d_pred$s2 <- rep(x, times = sapply(dates, length))

  out <-
    d_pred |>
    dplyr::nest_by(s2) |>
    tibble::deframe() |>
    as.list()

  return(out)
}

utils::globalVariables(c("air.2m", "hpbl", "acpcp", "rhum.2m",
                         "vis", "pres.sfc", "uwnd.10m", "vwnd.10m",
                         "urban_imperviousness_400",
                         "nei_point_id2w_1000", "census_tract_id_2010",
                         "predictions", "variance.estimates"))
