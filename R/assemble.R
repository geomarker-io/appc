#' Assemble predictors for the PM2.5 model
#'
#' Uses geomarker for environmental assessment and adds model-specific spatial
#' and calendar terms. The same implementation is used for training and prediction.
#' @param x a vector of level-30 `s2_cell` locations within the contiguous US
#' @param dates a list of nonempty Date vectors, the same length as `x`
#' @param pollutant reserved for future pollutant-specific predictors
#' @return A tibble with one row per requested location-date, in input order.
#'   Duplicate locations and dates are preserved.
#' @export
#' @examples
#' \dontrun{
#' assemble_predictors(
#'   s2::as_s2_cell("8841b39a7c46e25f"),
#'   list(as.Date(c("2023-05-18", "2023-11-06")))
#' )
#' }
assemble_predictors <- function(x, dates, pollutant = c("pm25")) {
  check_s2_dates(x, dates)
  # geomarker declares terra as optional, but this model always needs its rasters.
  loadNamespace("terra")
  spec <- model_spec()
  if (
    !all(s2::s2_intersects(
      s2::s2_cell_center(x),
      s2::as_s2_geography(contiguous_us)
    ))
  ) {
    stop(
      "not all s2 locations are within the contiguous united states",
      call. = FALSE
    )
  }

  # geomarker requires sorted dates; restore the caller's row order at the end.
  ordering <- lapply(dates, order)
  sorted_dates <- Map(function(d, i) d[i], dates, ordering)
  offsets <- cumsum(c(0L, utils::head(lengths(dates), -1L)))
  input_rows <- Map(function(i, offset) i + offset, ordering, offsets)
  locations <- geomarker::s2cd(x, sorted_dates)
  d <- tibble::tibble(s2 = x, dates = sorted_dates, .input_row = input_rows)
  coordinates <- sf::st_coordinates(sf::st_transform(
    sf::st_as_sf(s2::s2_cell_center(x)),
    spec$coordinate_crs
  ))
  d$x <- coordinates[, "X"]
  d$y <- coordinates[, "Y"]

  cli::cli_progress_step("adding elevation")
  elevation_median <- geomarker::get_elevation_summary(
    locations,
    fun = stats::median,
    buffer = spec$elevation_buffer
  )
  elevation_sd <- geomarker::get_elevation_summary(
    locations,
    fun = stats::sd,
    buffer = spec$elevation_buffer
  )
  if (
    !is.numeric(elevation_median) ||
      !is.numeric(elevation_sd) ||
      length(elevation_median) != length(x) ||
      length(elevation_sd) != length(x)
  ) {
    stop(
      "geomarker elevation summaries must contain one numeric value per location.",
      call. = FALSE
    )
  }
  d$elevation_median <- elevation_median
  d$elevation_sd <- elevation_sd

  cli::cli_progress_step("adding HMS smoke, NARR, and gridMET")
  d$plume_smoke <- geomarker::get_smoke_summary(
    locations,
    summary = spec$smoke_summary
  )
  d$hpbl <- geomarker::get_narr_data(locations, spec$narr_variable)
  for (name in names(spec$gridmet)) {
    d[[name]] <- geomarker::get_gridmet_data(locations, spec$gridmet[[name]])
  }
  cli::cli_progress_step("adding MERRA")
  merra <- geomarker::get_merra_data(locations)
  if (
    !is.list(merra) ||
      length(merra) != length(x) ||
      !all(vapply(
        merra,
        function(z) {
          is.data.frame(z) &&
            all(spec$merra_columns %in% names(z))
        },
        logical(1)
      ))
  ) {
    stop(
      "geomarker MERRA output does not have the expected schema.",
      call. = FALSE
    )
  }
  for (name in spec$merra_columns) {
    d[[name]] <- lapply(merra, `[[`, name)
  }

  temporal <- c("plume_smoke", "hpbl", names(spec$gridmet), spec$merra_columns)
  for (name in temporal) {
    z <- d[[name]]
    if (
      !is.list(z) ||
        length(z) != length(x) ||
        !all(vapply(z, is.numeric, logical(1))) ||
        !identical(unname(lengths(z)), unname(lengths(sorted_dates)))
    ) {
      stop(
        "geomarker output for ",
        name,
        " must contain one numeric value per requested location-date.",
        call. = FALSE
      )
    }
  }
  d <- tidyr::unnest(
    d,
    cols = dplyr::all_of(c("dates", ".input_row", temporal))
  )
  d <- dplyr::rename(d, date = dates)
  d <- d[order(d$.input_row), ]
  d$.input_row <- NULL
  d$year <- as.numeric(format(d$date, "%Y"))
  d$doy <- as.numeric(format(d$date, "%j"))
  cli::cli_progress_done()
  d
}
