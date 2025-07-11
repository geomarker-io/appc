test_that("get_hms_smoke_data() works", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2017-06-23")),
    "8841a45555555555" = as.Date(c("2017-06-22", "2023-08-15"))
  )
  get_hms_smoke_data(x = s2::as_s2_cell(names(d)), dates = d) |>
    expect_identical(list(c(9, 0), c(0, 2)))
})
