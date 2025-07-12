test_that("get_nei_point_summary works", {
  get_nei_point_summary(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    year = "2020",
    pollutant_code = "PM25-PRI",
    buffer = 1000
  ) |>
    expect_equal(c(6.30285480860561e-05, 1.77088909030131e-05))
  get_nei_point_summary(
    s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
    year = "2017",
    pollutant_code = "PMFINE",
    buffer = 1500
  ) |>
    expect_equal(c(7.45512086860517e-05, 2.20420317344646e-05))
})
