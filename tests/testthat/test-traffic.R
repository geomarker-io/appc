test_that("get_traffic_summary works", {
  get_traffic_summary(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123"))) |>
    expect_equal(list(
      `8841b399ced97c47` = list(aadt_total_m = 0, aadt_truck_m = 0),
      `8841b38578834123` = list(aadt_total_m = 0, aadt_truck_m = 0)
    ))

  get_traffic_summary(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), buffer = 1500) |>
    expect_equal(list(`8841b399ced97c47` = list(
      aadt_total_m = 659553870.545063,
      aadt_truck_m = 481087361966862
    ), `8841b38578834123` = list(
      aadt_total_m = 252742369.39041, aadt_truck_m = 281313235601750
    )))
})
