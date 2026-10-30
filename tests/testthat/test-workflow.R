test_that("the committed scripts build a small synthetic model used by prediction", {
  local_geomarker_sources()
  withr::local_envvar(R_USER_DATA_DIR = tempfile("appc-v3-synthetic-"))
  rm(list = ls(.appc_cache), envir = .appc_cache)
  withr::defer(rm(list = ls(.appc_cache), envir = .appc_cache))
  cells <- test_locations()[1:2]
  dates <- rep(
    list(as.Date(
      round(seq(
        as.numeric(model_spec()$coverage_start),
        as.numeric(model_spec()$coverage_end),
        length.out = 30
      )),
      origin = "1970-01-01"
    )),
    2
  )
  observations <- tibble::tibble(
    s2 = rep(cells, each = 30),
    date = do.call(c, dates),
    conc = c(seq(1, 15, length.out = 30), seq(3, 18, length.out = 30))
  )
  for_year <- function(year) {
    observations[format(observations$date, "%Y") == year, ]
  }
  testthat::local_mocked_bindings(
    get_daily_aqs = function(pollutant, year) {
      stopifnot(pollutant == "pm25")
      for_year(year)
    },
    install_aqs = function(year, force_reinstall) {
      stopifnot(year == "2026", force_reinstall)
      path <- tempfile(fileext = ".rds")
      saveRDS(for_year(year), path)
      path
    },
    .package = "appc"
  )
  # Exercise the actual two-step entry points with 60 synthetic outcome rows.
  work <- new.env(parent = globalenv())
  invisible(capture.output(suppressMessages(sys.source(
    system.file("make_training_data.R", package = "appc", mustWork = TRUE),
    envir = work
  ))))
  d <- readRDS(model_artifact_path("training"))
  expect_silent(validate_training_metadata(d))
  expect_equal(nrow(d), 60)
  invisible(capture.output(suppressMessages(sys.source(
    system.file("train_model.R", package = "appc", mustWork = TRUE),
    envir = work
  ))))
  model <- readRDS(model_artifact_path())
  request_cells <- cells[c(2, 1, 2)]
  request_dates <- list(
    dates[[1]][c(20, 1, 1)],
    dates[[1]][4],
    dates[[1]][10:11]
  )
  out <- predict_pm25(request_cells, request_dates, keep_predictors = TRUE)
  expect_identical(unname(vapply(out, nrow, integer(1))), c(3L, 1L, 2L))
  expect_identical(
    names(out[[1]]),
    c("pm25", "pm25_se", model_spec()$predictors)
  )
  expect_true(all(is.finite(unlist(lapply(out, function(z) z$pm25)))))
  expect_true(all(is.finite(unlist(lapply(out, function(z) z$pm25_se)))))
  expect_equal(out[[1]]$pm25[2], out[[1]]$pm25[3])
  expected <- assemble_predictors(request_cells, request_dates)
  direct <- stats::predict(
    model,
    expected[model_spec()$predictors],
    estimate.variance = TRUE
  )
  expect_equal(
    unlist(lapply(out, function(z) z$pm25), use.names = FALSE),
    as.numeric(direct$predictions)
  )
})

test_that("missing v3 artifacts fail without downloading or using cached v2", {
  withr::local_envvar(R_USER_DATA_DIR = tempfile("appc-no-v3-"))
  rm(list = ls(.appc_cache), envir = .appc_cache)
  withr::defer(rm(list = ls(.appc_cache), envir = .appc_cache))
  dir.create(dirname(model_artifact_path()), recursive = TRUE)
  saveRDS(
    "v2 must not be used",
    file.path(dirname(model_artifact_path()), "rf_pm_v2.rds")
  )
  expect_error(
    predict_pm25(test_locations()[1], test_dates()[1]),
    "build it locally"
  )
})

test_that("local artifacts with incompatible metadata or schemas are rejected", {
  withr::local_envvar(R_USER_DATA_DIR = tempfile("appc-bad-v3-"))
  rm(list = ls(.appc_cache), envir = .appc_cache)
  withr::defer(rm(list = ls(.appc_cache), envir = .appc_cache))
  dir.create(dirname(model_artifact_path()), recursive = TRUE)
  saveRDS("old model", model_artifact_path())
  expect_error(load_rf_pm_model(), "metadata")
  object <- structure(
    list(X.orig = data.frame(wrong = 1)),
    appc_model_training = training_metadata(),
    class = "regression_forest"
  )
  saveRDS(object, model_artifact_path())
  expect_error(load_rf_pm_model(), "predictor schema")
})

test_that("AQS requests use the names returned by needenv", {
  withr::local_envvar(
    AQS_DATA_MART_API_EMAIL = "test@example.invalid",
    AQS_DATA_MART_API_KEY = "test-key"
  )
  testthat::local_mocked_bindings(
    req_perform_sequential = function(reqs) reqs,
    .package = "httr2"
  )
  requests <- aqs_data_mart_daily("2026")
  query <- httr2::url_parse(requests[[1]]$url)$query
  expect_identical(query$email, "test@example.invalid")
  expect_identical(query$key, "test-key")
})
