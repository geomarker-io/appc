aqs_test_response <- function(state) {
  body <- sprintf(
    paste0(
      '{"Header":[{"status":"Success"}],"Data":[{',
      '"sample_duration":"24 HOUR","observation_percent":100,',
      '"validity_indicator":"Y","state_code":"%s","county_code":"001",',
      '"site_number":"0001","latitude":%s,"longitude":-84.5,',
      '"arithmetic_mean":%s,"date_local":"2026-06-30"}]}'
    ),
    state,
    39 + as.numeric(state) / 100,
    as.numeric(state)
  )
  httr2::response(
    headers = list("content-type" = "application/json"),
    body = charToRaw(body)
  )
}

test_that("a failed AQS refresh resumes completed states and preserves the annual cache", {
  withr::local_envvar(
    R_USER_DATA_DIR = tempfile("appc-aqs-resume-"),
    AQS_DATA_MART_API_EMAIL = "test@example.invalid",
    AQS_DATA_MART_API_KEY = "test-key"
  )
  requests <- aqs_data_mart_requests("2026")[c("01", "04")]
  calls <- character()
  fail <- TRUE
  testthat::local_mocked_bindings(
    aqs_data_mart_requests = function(year) requests
  )
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      state <- httr2::url_parse(req$url)$query$state
      calls <<- c(calls, state)
      if (state == "04" && fail) {
        stop("HTTP 502 Bad Gateway")
      }
      aqs_test_response(state)
    },
    .package = "httr2"
  )
  root <- tools::R_user_dir("appc", "data")
  dir.create(root, recursive = TRUE)
  final <- file.path(root, "aqs_2026.rds")
  saveRDS("previous complete extract", final)
  expect_error(install_aqs("2026", force_reinstall = TRUE), "502 Bad Gateway")
  expect_identical(readRDS(final), "previous complete extract")
  expect_true(file.exists(file.path(root, "aqs_2026_partial", "01.rds")))
  expect_false(file.exists(file.path(root, "aqs_2026_partial", "04.rds")))

  fail <- FALSE
  expect_identical(
    normalizePath(install_aqs("2026", force_reinstall = TRUE)),
    normalizePath(final)
  )
  expect_identical(calls, c("01", "04", "04"))
  out <- readRDS(final)
  expect_named(out, c("s2", "date", "conc"))
  expect_equal(nrow(out), 2)
  expect_equal(sort(out$conc), c(1, 4))
  expect_length(list.files(file.path(root, "aqs_2026_partial")), 0)
  # A later forced refresh must not reuse states from a completed refresh.
  install_aqs("2026", force_reinstall = TRUE)
  expect_identical(calls, c("01", "04", "04", "01", "04"))
})

test_that("AQS requests retry transient failures and cover the contiguous states", {
  withr::local_envvar(
    AQS_DATA_MART_API_EMAIL = "test@example.invalid",
    AQS_DATA_MART_API_KEY = "test-key"
  )
  requests <- aqs_data_mart_requests("2026")
  expect_length(requests, 49)
  expect_true(all(c("16", "38") %in% names(requests)))
  expect_false(any(c("02", "15") %in% names(requests)))
  policy <- requests[[1]]$policies
  expect_equal(policy$retry_max_tries, 4)
  expect_true(policy$retry_on_failure)
  for (status in c(429L, 500L, 502L, 503L, 504L)) {
    expect_true(policy$retry_is_transient(httr2::response(
      status_code = status
    )))
  }
  expect_false(policy$retry_is_transient(httr2::response(status_code = 400L)))
})
