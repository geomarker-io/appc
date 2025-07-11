if (file.exists(".env")) dotenv::load_dot_env()
earthdata_secrets <- Sys.getenv(
  c("EARTHDATA_USERNAME", "EARTHDATA_PASSWORD"),
  unset = NA
)
skip_if(
  any(is.na(earthdata_secrets)),
  message = "no earthdata credentials found"
)
skip_if_offline()
skip_if(Sys.getenv("CI") == "", "not on a CI platform")
skip_if(
  is.null(curl::nslookup("gesdisc.eosdis.nasa.gov", error = FALSE)),
  "NASA GES DISC not online"
)

test_that("getting daily merra from GES DISC works", {
  # "normal" pattern
  # merra site uses 401 instead of 400 for september 2020 dates
  # merra site uses 401 instead of 400 for jun, jul, aug, sep 2021 dates
  out <-
    list(
      create_daily_merra_data("2023-05-23"),
      create_daily_merra_data(merra_date = "2020-09-02"),
      create_daily_merra_data(merra_date = "2021-06-16")
    )
  expect_equal(sapply(out, nrow), c(4800, 4800, 4800))
})
