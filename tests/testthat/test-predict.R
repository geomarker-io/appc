test_that("predict_pm25() works", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
  )
  out <- predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)
  expect_identical(sapply(out, nrow), c(2L, 2L))
  expect_length(out, 2)
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
