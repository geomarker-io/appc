test_that("model cache is keyed by artifact version", {
  models <- withr::with_envvar(
    c(R_USER_DATA_DIR = tempfile("appc-model-cache")),
    {
      data_dir <- tools::R_user_dir("appc", "data")
      dir.create(data_dir, recursive = TRUE)
      saveRDS("first", fs::path(data_dir, "rf_pm_vtest1.rds"))
      saveRDS("second", fs::path(data_dir, "rf_pm_vtest2.rds"))
      rm(list = ls(.appc_cache), envir = .appc_cache)
      list(
        first = load_rf_pm_model("test1"),
        second = load_rf_pm_model("test2")
      )
    }
  )
  rm(list = ls(.appc_cache), envir = .appc_cache)

  expect_identical(models$first, "first")
  expect_identical(models$second, "second")
})

test_that("model artifacts are checksum verified", {
  model_file <- tempfile("appc-model-checksum")
  writeLines("test model", model_file)
  sha256sum <- get0(
    "sha256sum",
    envir = asNamespace("tools"),
    inherits = FALSE
  )
  checksums <- c(
    sha256 = if (is.null(sha256sum)) {
      "unused"
    } else {
      unname(sha256sum(model_file))
    },
    md5 = unname(tools::md5sum(model_file))
  )

  expect_true(rf_pm_model_checksum_matches(model_file, checksums))
  checksums[] <- "incorrect"
  expect_false(rf_pm_model_checksum_matches(model_file, checksums))
  expect_true(rf_pm_model_checksum_matches(model_file, NULL))
})

test_that("predict_pm25() works", {
  skip_if_not_integration()
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
  )
  out <- predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)
  expect_identical(sapply(out, nrow), c(2L, 2L))
  expect_length(out, 2)
  # keep predictors works
  out <- predict_pm25(
    x = s2::as_s2_cell(names(d)),
    dates = d,
    keep_predictors = TRUE
  )
  expect_length(names(out[[1]]), 22)
})

test_that("predict_pm25() validates locations before loading the model", {
  expect_error(
    predict_pm25(
      s2::as_s2_cell(c("8841b39a7c46e25f", NA)),
      list(
        as.Date(c("2023-05-18", "2023-11-06")),
        as.Date(c("2023-06-22", "2023-08-15"))
      )
    ),
    "not contain any missing values"
  )
})

test_that("predict_pm25() covers late 2025 through June 30, 2026", {
  skip_if_not_integration()
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2025-12-31", "2026-06-30"))
  )
  out <- predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)

  expect_identical(sapply(out, nrow), 2L)
  expect_true(all(is.finite(out[[1]]$pm25)))
  expect_true(all(is.finite(out[[1]]$pm25_se)))
})

test_that("predict_pm25() works with duplicated locations", {
  skip_if_not_integration()
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841b39a7c46e25f" = as.Date(c("2023-06-22", "2023-08-15"))
  )
  out <- predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)
  expect_identical(sapply(out, nrow), c(2L, 2L))
  expect_length(out, 2)
})

test_that("predict_pm25_date_range() works", {
  skip_if_not_integration()
  out <- predict_pm25_date_range(
    x = c("8841b39a7c46e25f", "8841a45555555555"),
    start_date = as.Date(c("2023-05-18", "2023-01-06")),
    end_date = as.Date(c("2023-06-22", "2023-08-15"))
  )
  expect_length(out, 2)
  expect_identical(sapply(out, nrow), c(36L, 222L))

  out_averaged <- predict_pm25_date_range(
    x = c("8841b39a7c46e25f", "8841a45555555555"),
    start_date = as.Date(c("2023-05-18", "2023-01-06")),
    end_date = as.Date(c("2023-06-22", "2023-08-15")),
    average = TRUE
  )
  expect_length(out_averaged, 2)
  expect_identical(sapply(out_averaged, nrow), c(1L, 1L))
})
