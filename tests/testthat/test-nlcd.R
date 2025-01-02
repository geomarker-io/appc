test_that("get_nlcd_frac_imperv works", {
  testthat::skip_on_ci()
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841a45555555555" = as.Date(c("2022-06-22", "2022-08-15"))
  )
  get_nlcd_frac_imperv(x = s2::as_s2_cell(names(d)), dates = d) |>
    expect_equal(
      list(
        `8841b39a7c46e25f` = c(`2023` = 70, `2023` = 70),
        `8841a45555555555` = c(`2022` = 8, `2022` = 8)
      )
    )
  get_nlcd_frac_imperv(x = s2::as_s2_cell(names(d)), dates = d, fun = max, buffer = 1000) |>
    expect_equal(
      list(
        `8841b39a7c46e25f` = c(`2023` = 93, `2023` = 93),
        `8841a45555555555` = c(`2022` = 95, `2022` = 95)
      )
    )
})
