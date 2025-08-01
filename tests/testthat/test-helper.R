test_that("check_s2_dates() works", {
  check_s2_dates(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123"))) |>
    expect_silent()

  s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")) |>
    s2::s2_cell_parent(29) |>
    check_s2_dates() |>
    expect_error("s2 cell levels must be 30")

  check_s2_dates(c("8841b399ced97c47", "8841b38578834123")) |>
    expect_error("s2_cell vector")

  check_s2_dates(s2::as_s2_cell(c("8841b399ced97c47", NA))) |>
    expect_error("missing values")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2023-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06", "2023-11-07"))
    )
  ) |>
    expect_silent()

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    c(
      as.Date(c("2023-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06"))
    )
  ) |>
    expect_error("same length")

  check_s2_dates(
    s2::as_s2_cell(c(
      "8841b399ced97c47",
      "8841b38578834123",
      "8841b399ced97c47"
    )),
    list(
      as.Date(c("2023-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06"))
    )
  ) |>
    expect_error("same length")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(as.Date(c("2023-05-18", "2023-11-06")))
  ) |>
    expect_error("same length")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2023-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06"))
    )
  ) |>
    expect_silent()

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      c("2023-06-22", "2023-08-15"),
      c("2023-05-18", "2023-11-06", "2023-11-07")
    )
  ) |>
    expect_error("must be `Date` objects")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2016-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06", "2023-11-07"))
    ),
    check_date_min = "2020-03-22"
  ) |>
    expect_error("must be later than")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2016-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06", "2023-11-07"))
    ),
    check_date_max = "2020-03-22"
  ) |>
    expect_error("must be later than")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2016-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06", "2023-11-07"))
    ),
    check_date_max = "2020-03-22",
    check_date_min = NULL
  ) |>
    expect_error("must be earlier than")

  # ensure max is properly dealt with
  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2017-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06", "2024-12-31"))
    ),
    check_date_max = "2024-12-31"
  ) |>
    expect_silent()

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2016-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06", "2023-11-07"))
    )
  ) |>
    expect_error("must be later than")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2017-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06", "2025-01-07"))
    )
  ) |>
    expect_error("must be earlier than")

  check_s2_dates(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    list(
      as.Date(c("2016-06-22", "2023-08-15")),
      as.Date(c("2023-05-18", "2023-11-06", "2023-11-07"))
    ),
    check_date_min = NULL,
    check_date_max = NULL
  ) |>
    expect_silent()
})

test_that("get_closest_year() works", {
  get_closest_year(
    x = as.Date(c("2021-09-15", "2022-09-01")),
    years = c(2020, 2022)
  ) |>
    expect_error("must be a character vector")

  get_closest_year(
    x = as.Date(c("2021-09-15", "2022-09-01")),
    years = c("2020", "2022")
  ) |>
    expect_equal(c("2022", "2022"))

  get_closest_year(
    x = as.Date(c("2021-03-15", "2022-09-01")),
    years = c("2020", "2022")
  ) |>
    expect_equal(c("2020", "2022"))
})
