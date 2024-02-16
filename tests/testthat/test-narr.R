test_that("get_narr_data() works", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2022-05-18", "2022-11-06")),
    "8841a45555555555" = as.Date(c("2022-06-22", "2022-08-15"))
  )
  out <- get_narr_data(x = s2::as_s2_cell(names(d)), dates = d, narr_var = "air.2m")
  expect_identical(sapply(out, length), c(`8841b39a7c46e25f` = 2L, `8841a45555555555` = 2L))
  out |>
    expect_named() |>
    expect_length(2)
})
