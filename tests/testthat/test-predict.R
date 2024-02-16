skip_on_ci()
test_that("predict_pm25() works", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
  )
  out <- predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)
  expect_identical(sapply(out, nrow), c(`8841b39a7c46e25f` = 2L, `8841a45555555555` = 2L))
  out |>
    expect_named() |>
    expect_length(2)
})

