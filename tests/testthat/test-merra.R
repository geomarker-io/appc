test_that("get_merra_data works", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
  )
  get_merra_data(x = s2::as_s2_cell(names(d)), dates = d) |>
    expect_snapshot()
})
