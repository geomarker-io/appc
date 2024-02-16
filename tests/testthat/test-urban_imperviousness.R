test_that("get_urban_imperviousness works", {
  get_urban_imperviousness(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), year = "2021") |>
    expect_equal(c(`8841b399ced97c47` = 74.3225806451613, `8841b38578834123` = 33.6276978417266))
  get_urban_imperviousness(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), year = "2021", buffer = 800) |>
    expect_equal(c(`8841b399ced97c47` = 63.9446693657218, `8841b38578834123` = 46.8727517985612))
})
