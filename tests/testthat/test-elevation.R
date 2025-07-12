test_that("get_elevation_summary works", {
  get_elevation_summary(s2::as_s2_cell(c(
    "8841b399ced97c47",
    "8841b38578834123"
  ))) |>
    expect_equal(c(231, 222.5))
  get_elevation_summary(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    fun = sd
  ) |>
    expect_equal(c(11.3137084989848, 0.707106781186548))
  get_elevation_summary(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    buffer = 1000
  ) |>
    expect_equal(c(241.5, 223))
  get_elevation_summary(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    buffer = 1000,
    fun = mean
  ) |>
    expect_equal(c(239.75, 229))
  get_elevation_summary(s2::as_s2_cell(c(
    "8841b399ced97c47",
    "8841b38578834123"
  ))) |>
    expect_equal(c(231, 222.5))
})
