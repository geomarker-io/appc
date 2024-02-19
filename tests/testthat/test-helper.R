test_that("check_s2_dates() works", {
  check_s2_dates(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123"))) |>
    expect_silent()

  check_s2_dates(c("8841b399ced97c47", "8841b38578834123")) |>
    expect_error("s2_cell vector")

  check_s2_dates(s2::as_s2_cell(c("8841b399ced97c47", NA))) |>
    expect_error("missing values")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(as.Date(c("2023-06-22", "2023-08-15")), as.Date(c("2023-05-18", "2023-11-06", "2023-11-07")))
  ) |>
    expect_silent()

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    c(as.Date(c("2023-06-22", "2023-08-15")), as.Date(c("2023-05-18", "2023-11-06")))
  ) |>
    expect_error("same length")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123", "8841b399ced97c47")),
    c(as.Date(c("2023-06-22", "2023-08-15")), as.Date(c("2023-05-18", "2023-11-06")))
  ) |>
    expect_error("same length")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(as.Date(c("2023-05-18", "2023-11-06")))
  ) |>
    expect_error("same length")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(as.Date(c("2023-06-22", "2023-08-15")), as.Date(c("2023-05-18", "2023-11-06")))
  ) |>
    expect_silent()

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(c("2023-06-22", "2023-08-15"), c("2023-05-18", "2023-11-06", "2023-11-07"))
  ) |>
    expect_error("must be `Date` objects")
})
