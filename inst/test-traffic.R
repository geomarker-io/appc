test_that("get_traffic_summary works", {
  get_traffic_summary(x = s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123"))) |>
    expect_equal(
      list(`8841b399ced97c47` = list(
        aadt_total_m = 16697223.3895544,
        aadt_truck_m = 14454627503016.2
      ), `8841b38578834123` = list(
        aadt_total_m = 33445517.3970626,
        aadt_truck_m = 28953466354329.6
      ))
    )
  get_traffic_summary(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")), buffer = 1500) |>
    expect_equal(
      list(`8841b399ced97c47` = list(
        aadt_total_m = 657047536.321914,
        aadt_truck_m = 430564143157840
      ), `8841b38578834123` = list(
        aadt_total_m = 225667410.451303,
        aadt_truck_m = 201099749546257
      )))
})
