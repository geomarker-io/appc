test_that("the committed scripts build a small synthetic model used by prediction", {
  local_geomarker_sources()
  # Synthetic forests exercise the workflow independently of release binaries.
  testthat::local_mocked_bindings(.rf_pm_model_checksums = list())
  withr::local_options(appc.refresh_aqs = NULL)
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
  refreshes <- logical()
  testthat::local_mocked_bindings(
    get_daily_aqs = function(pollutant, year) {
      stopifnot(pollutant == "pm25")
      for_year(year)
    },
    install_aqs = function(year, force_reinstall) {
      stopifnot(year == "2026")
      refreshes <<- c(refreshes, force_reinstall)
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
  # Restarting predictor assembly can reuse a successfully refreshed AQS cache.
  unlink(model_artifact_path("training"))
  withr::local_options(appc.refresh_aqs = FALSE)
  invisible(capture.output(suppressMessages(sys.source(
    system.file("make_training_data.R", package = "appc", mustWork = TRUE),
    envir = work
  ))))
  expect_identical(refreshes, c(TRUE, FALSE))
  resumed <- readRDS(model_artifact_path("training"))
  expect_silent(validate_training_metadata(resumed))
  for (column in names(d)) {
    expect_identical(resumed[[column]], d[[column]])
  }
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
  # The s2cd method must produce exactly the same results as explicit vectors.
  sorted_dates <- lapply(request_dates, sort)
  locations <- geomarker::s2cd(request_cells, sorted_dates)
  expect_equal(
    predict_pm25(locations, keep_predictors = TRUE),
    predict_pm25(request_cells, sorted_dates, keep_predictors = TRUE)
  )
  plain <- predict_pm25(locations)
  expect_identical(names(plain[[1]]), c("pm25", "pm25_se"))
  expect_identical(unname(vapply(plain, nrow, integer(1))), c(3L, 1L, 2L))
})

test_that("unregistered models fail without downloading or using cached v2", {
  withr::local_envvar(R_USER_DATA_DIR = tempfile("appc-no-v3-"))
  rm(list = ls(.appc_cache), envir = .appc_cache)
  withr::defer(rm(list = ls(.appc_cache), envir = .appc_cache))
  dir.create(dirname(model_artifact_path()), recursive = TRUE)
  saveRDS(
    "v2 must not be used",
    file.path(dirname(model_artifact_path()), "rf_pm_v2.rds")
  )
  expect_error(
    load_rf_pm_model("unregistered"),
    "build it locally"
  )
})

test_that("a missing v3 model requests the registered artifact without using v2", {
  withr::local_envvar(R_USER_DATA_DIR = tempfile("appc-download-v3-"))
  rm(list = ls(.appc_cache), envir = .appc_cache)
  withr::defer(rm(list = ls(.appc_cache), envir = .appc_cache))
  dir.create(dirname(model_artifact_path()), recursive = TRUE)
  v2 <- file.path(dirname(model_artifact_path()), "rf_pm_v2.rds")
  saveRDS("cached v2", v2)
  model <- structure(
    list(
      X.orig = as.data.frame(stats::setNames(
        rep(list(1), length(model_spec()$predictors)),
        model_spec()$predictors
      ))
    ),
    appc_model_training = training_metadata(),
    class = "regression_forest"
  )
  requested <- NULL
  testthat::local_mocked_bindings(
    download_rf_pm_model = function(path, model_version, checksums) {
      requested <<- list(
        path = path,
        version = model_version,
        checksums = checksums
      )
      saveRDS(model, path)
      invisible(path)
    }
  )
  expect_identical(load_rf_pm_model(), model)
  expect_identical(requested$version, "3")
  expect_identical(requested$checksums, .rf_pm_model_checksums[["3"]])
  expect_identical(basename(requested$path), "rf_pm_v3.rds")
  expect_identical(readRDS(v2), "cached v2")
})

test_that("local artifacts with incompatible metadata or schemas are rejected", {
  testthat::local_mocked_bindings(.rf_pm_model_checksums = list())
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
