test_that("assemble_predictors() works", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
  )
  out <- assemble_predictors(x = s2::as_s2_cell(names(d)), dates = d)
  expect_equal(nrow(out), 4)
  # missing s2 location errors
  assemble_predictors(
    s2::as_s2_cell(c("8841b39a7c46e25f", NA)),
    list(
      as.Date(c("2023-05-18", "2023-11-06")),
      as.Date(c("2023-06-22", "2023-08-15"))
    )
  ) |>
    expect_error("not contain any missing values")
})
