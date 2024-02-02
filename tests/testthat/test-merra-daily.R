if (file.exists(".env")) dotenv::load_dot_env()
earthdata_secrets <- Sys.getenv(c("EARTHDATA_USERNAME", "EARTHDATA_PASSWORD"), unset = NA)
skip_if(any(is.na(earthdata_secrets)), message = "no earthdata credentials found")

test_that("getting daily merra from GES DISC works", {
  # plus these tests take a long time to download the raw merra data

  # "normal" pattern
  create_daily_merra_data("2023-05-23") |>
    expect_snapshot()
  # merra site uses 401 instead of 400 for september 2020 dates
  create_daily_merra_data(merra_date = "2020-09-02") |>
    expect_snapshot()
  # merra site uses 401 instead of 400 for jun, jul, aug, sep 2021 dates
  create_daily_merra_data(merra_date = "2021-06-16") |>
    expect_snapshot()
  create_daily_merra_data(merra_date = "2021-05-21") |>
    expect_snapshot()
})
