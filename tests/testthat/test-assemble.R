test_that("assembly restores location and date order with duplicates", {
  local_geomarker_sources()
  cells <- test_locations()
  dates <- test_dates()
  d <- assemble_predictors(cells, dates)
  expect_identical(as.character(d$s2), rep(as.character(cells), lengths(dates)))
  expect_identical(d$date, do.call(c, dates))
  expect_identical(
    names(d),
    c(
      "s2",
      "date",
      "x",
      "y",
      "elevation_median",
      "elevation_sd",
      "plume_smoke",
      "hpbl",
      names(model_spec()$gridmet),
      model_spec()$merra_columns,
      "year",
      "doy"
    )
  )
  expect_true(all(vapply(d[model_spec()$predictors], is.numeric, logical(1))))
  expect_identical(
    d$temperature_max,
    unlist(
      fixture_values(geomarker::s2cd(cells, lapply(dates, sort))),
      use.names = FALSE
    )[
      c(3, 1, 2, 4, 5, 6)
    ]
  )
  expect_equal(d$plume_smoke, rep(6, 6))
  expect_equal(d$doy[4], 60)
  expect_equal(d$year[4], 2024)
  expect_identical(d$temperature_max[2], d$temperature_max[3])
})

test_that("training outcomes are attached only to matching S2/date rows", {
  local_geomarker_sources()
  cells <- test_locations()
  dates <- test_dates()
  d <- assemble_predictors(cells, dates)
  outcome <- list(c(30, 10, 10), 20, c(40, 50))
  expect_identical(
    attach_training_outcome(d, cells, dates, outcome)$conc,
    c(30, 10, 10, 20, 40, 50)
  )
  expect_error(
    attach_training_outcome(d[c(2, 1, 3:6), ], cells, dates, outcome),
    "do not align"
  )
  d$s2[1] <- cells[2]
  expect_error(
    attach_training_outcome(d, cells, dates, outcome),
    "do not align"
  )
})

test_that("source vectors cannot be silently recycled across dates", {
  local_geomarker_sources()
  testthat::local_mocked_bindings(
    get_gridmet_data = function(x, gridmet_var) rep(list(1), length(x)),
    .package = "geomarker"
  )
  expect_error(
    assemble_predictors(test_locations(), test_dates()),
    "one numeric value"
  )
})

test_that("assessment missing values are preserved and factor smoke is rejected", {
  local_geomarker_sources()
  testthat::local_mocked_bindings(
    get_narr_data = function(x, narr_var) {
      lapply(geomarker::s2cd_dates(x), function(d) rep(NA_real_, length(d)))
    },
    .package = "geomarker"
  )
  expect_true(all(is.na(
    assemble_predictors(test_locations(), test_dates())$hpbl
  )))
  testthat::local_mocked_bindings(
    get_smoke_summary = function(x, summary) {
      lapply(geomarker::s2cd_dates(x), function(d) {
        factor(rep("Heavy", length(d)))
      })
    },
    .package = "geomarker"
  )
  expect_error(
    assemble_predictors(test_locations(), test_dates()),
    "plume_smoke"
  )
})

test_that("assembly rejects missing, coarse, empty, and out-of-CONUS requests", {
  cells <- test_locations()
  expect_error(
    assemble_predictors(
      s2::as_s2_cell(c(NA, as.character(cells[1]))),
      test_dates()[1:2]
    ),
    "missing values"
  )
  expect_error(
    assemble_predictors(
      c(cells[1], s2::s2_cell_parent(cells[2], 29)),
      test_dates()[1:2]
    ),
    "levels"
  )
  expect_error(
    assemble_predictors(cells[1], list(as.Date(character()))),
    "nonempty"
  )
  expect_error(
    assemble_predictors(cells[1], list(as.Date(NA))),
    "missing values"
  )
  outside <- s2::as_s2_cell(s2::s2_lnglat(-157.8, 21.3))
  expect_error(assemble_predictors(outside, test_dates()[2]), "contiguous")
})

test_that("released geomarker sums overlapping plume scores", {
  testthat::local_mocked_bindings(
    get_daily_smoke_data = function(x, ...) {
      geometry <- s2::s2_geog_from_text(rep(
        "POLYGON ((-85 38, -84 38, -84 40, -85 40, -85 38))",
        3
      ))
      daily <- tibble::tibble(
        geometry = geometry,
        density = ordered(
          c("Light", "Medium", "Heavy"),
          levels = c("None", "Light", "Medium", "Heavy")
        )
      )
      stats::setNames(rep(list(daily), length(x)), as.character(x))
    },
    .package = "geomarker"
  )
  cells <- s2::as_s2_cell(s2::s2_lnglat(c(-84.5, -80), c(39, 39)))
  x <- geomarker::s2cd(cells, rep(list(as.Date("2024-01-01")), 2))
  out <- geomarker::get_smoke_summary(x, summary = "sum")
  expect_equal(unname(out[[1]]), 6)
  expect_equal(unname(out[[2]]), 0)
})
