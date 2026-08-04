test_that("model cache is keyed by artifact version", {
  models <- withr::with_envvar(
    c(R_USER_DATA_DIR = tempfile("appc-model-cache")),
    {
      data_dir <- tools::R_user_dir("appc", "data")
      dir.create(data_dir, recursive = TRUE)
      qs2::qs_save("v1", fs::path(data_dir, "rf_pm_v1.qs2"))
      qs2::qs_save("v2", fs::path(data_dir, "rf_pm_v2.qs2"))
      rm(list = ls(.appc_cache), envir = .appc_cache)
      list(
        v1 = load_rf_pm_model("1"),
        v2 = load_rf_pm_model("2")
      )
    }
  )
  rm(list = ls(.appc_cache), envir = .appc_cache)

  expect_identical(models$v1, "v1")
  expect_identical(models$v2, "v2")
})

test_that("predict_pm25() works", {
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
  # missing s2 location errors
  predict_pm25(
    s2::as_s2_cell(c("8841b39a7c46e25f", NA)),
    list(
      as.Date(c("2023-05-18", "2023-11-06")),
      as.Date(c("2023-06-22", "2023-08-15"))
    )
  ) |>
    expect_error("not contain any missing values")
})

test_that("predict_pm25() covers late 2025 through June 30, 2026", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2025-12-31", "2026-06-30"))
  )
  out <- predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)

  expect_identical(sapply(out, nrow), 2L)
  expect_true(all(is.finite(out[[1]]$pm25)))
  expect_true(all(is.finite(out[[1]]$pm25_se)))
})

test_that("predict_pm25() works with duplicated locations", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841b39a7c46e25f" = as.Date(c("2023-06-22", "2023-08-15"))
  )
  out <- predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)
  expect_identical(sapply(out, nrow), c(2L, 2L))
  expect_length(out, 2)
})

test_that("predict_pm25_date_range() works", {
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
