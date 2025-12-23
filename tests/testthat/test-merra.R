test_that("get_merra_data works", {
  d <- list(
    "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
    "8841a45555555555" = as.Date(c("2023-06-22", "2025-10-31"))
  )
  out <- get_merra_data(x = s2::as_s2_cell(names(d)), dates = d)
  expect_equal(length(out), 2)
  expect_equal(
    lapply(out, nrow),
    list("8841b39a7c46e25f" = 2, "8841a45555555555" = 2)
  )
  expect_equal(
    out$`8841b39a7c46e25f`$merra_dust,
    c(1.77165780194481, 0.841950516250467)
  )
})
