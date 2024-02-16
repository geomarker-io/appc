test_that("get_census_tract_id works", {

  get_census_tract_id(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), year = "2020") |>
    expect_equal(c(`8841b399ced97c47` = "39061003200", `8841b38578834123` = "39061003000"))

  get_census_tract_id(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), year = "2019") |>
    expect_equal(c(`8841b399ced97c47` = "39061003200", `8841b38578834123` = "39061003000"))

  get_census_tract_id(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), year = "2014") |>
    expect_equal(c(`8841b399ced97c47` = "39061003200", `8841b38578834123` = "39061003000"))

  get_census_tract_id(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), year = "2010") |>
    expect_equal(c(`8841b399ced97c47` = "39061003200", `8841b38578834123` = "39061003000"))

  get_census_tract_id(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), year = "2023") |>
    expect_equal(c(`8841b399ced97c47` = "39061003200", `8841b38578834123` = "39061003000"))

  # TODO add tests with examples where locations change tracts over time
  
})
