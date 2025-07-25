skip_if_offline()
skip_if(
  is.null(curl::nslookup("aqs.epa.gov", error = FALSE)),
  "EPA AQS not online"
)

test_that("get_daily_aqs() works", {
  aqs_pm <- get_daily_aqs("pm25", "2023")
  expect_equal(names(aqs_pm), c("s2", "date", "pollutant", "conc"))
  expect_s3_class(aqs_pm, c("tbl_df", "tbl", "data.frame"))
  aqs_ozone <- get_daily_aqs("ozone", "2022")
  expect_equal(names(aqs_ozone), c("s2", "date", "pollutant", "conc"))
  expect_s3_class(aqs_ozone, c("tbl_df", "tbl", "data.frame"))
  aqs_no2 <- get_daily_aqs("ozone", "2021")
  expect_equal(names(aqs_no2), c("s2", "date", "pollutant", "conc"))
  expect_s3_class(aqs_no2, c("tbl_df", "tbl", "data.frame"))
})
