test_that("install_smoke_pm_data() works", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
  )
  d_smoke <- readRDS(install_smoke_pm_data())
  d_smoke |>
    expect_named() |>
    expect_s3_class("tbl") |>
    expect_length(3)
})