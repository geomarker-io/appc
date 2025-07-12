test_that("latlon_to_s2_cell() works", {
  latlon_to_s2_cell(
    lat = c(45.0, 46.1),
    lon = c(-64.2, -65.3)
  ) |>
    expect_identical(s2::as_s2_cell(c(
      "4b59a92b6f051e97",
      "4ca0d6ffa227170d"
    ))) |>
    s2::s2_cell_level() |>
    expect_identical(c(30L, 30L))
})
