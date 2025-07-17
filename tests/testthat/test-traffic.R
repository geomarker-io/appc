test_that("get_traffic_summary works", {
  get_traffic_summary(
    s2::as_s2_cell(c(
      "8841b6abd8207619",
      "8841b4f6affffffb",
      "8841b39f07f7d899"
    ))
  ) |>
    lapply(round, digits = -1) |>
    expect_identical(
      list(
        `8841b6abd8207619` = c(
          aadtm_trucks_buses = 10455080,
          aadtm_tractor_trailer = 18769360,
          aadtm_passenger = 230570820
        ),
        `8841b4f6affffffb` = c(
          aadtm_trucks_buses = 9693260,
          aadtm_tractor_trailer = 4764290,
          aadtm_passenger = 149804920
        ),
        `8841b39f07f7d899` = c(
          aadtm_trucks_buses = 0,
          aadtm_tractor_trailer = 0,
          aadtm_passenger = 0
        )
      )
    )
})
