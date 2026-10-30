# Deterministic source responses for contract tests; no source files are read.
fixture_values <- function(x) {
  longitude <- as.data.frame(s2::s2_cell_to_lnglat(s2::as_s2_cell(x)))$x
  dates <- geomarker::s2cd_dates(x)
  lapply(seq_along(x), function(i) {
    as.numeric(dates[[i]]) + longitude[[i]] / 1000
  })
}

local_geomarker_sources <- function(.env = parent.frame()) {
  testthat::local_mocked_bindings(
    get_elevation_summary = function(x, fun, buffer) {
      stopifnot(buffer == 1200)
      longitude <- as.data.frame(s2::s2_cell_to_lnglat(s2::as_s2_cell(x)))$x
      longitude + if (identical(fun, stats::sd)) 100 else 300
    },
    get_smoke_summary = function(x, summary) {
      stopifnot(summary == "sum")
      lapply(geomarker::s2cd_dates(x), function(d) rep(6, length(d)))
    },
    get_narr_data = function(x, narr_var) {
      stopifnot(narr_var == "hpbl")
      fixture_values(x)
    },
    get_gridmet_data = function(x, gridmet_var) {
      stopifnot(
        gridmet_var %in% c("tmmx", "tmmn", "pr", "srad", "vs", "th", "sph")
      )
      fixture_values(x)
    },
    get_merra_data = function(x) {
      lapply(fixture_values(x), function(values) {
        as.data.frame(stats::setNames(
          rep(list(values), 6),
          c(
            "merra_dust",
            "merra_oc",
            "merra_bc",
            "merra_ss",
            "merra_so4",
            "merra_pm25"
          )
        ))
      })
    },
    .package = "geomarker",
    .env = .env
  )
}

test_locations <- function() {
  s2::as_s2_cell(c("8841b39a7c46e25f", "8841a45555555555", "8841b39a7c46e25f"))
}

test_dates <- function() {
  list(
    as.Date(c("2023-11-06", "2023-05-18", "2023-05-18")),
    as.Date("2024-02-29"),
    as.Date(c("2017-01-01", "2026-06-30"))
  )
}
