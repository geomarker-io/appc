skip_if_offline()
skip_if(
  is.null(curl::nslookup("aqs.epa.gov", error = FALSE)),
  "EPA AQS not online"
)

test_that("get_daily_aqs() works", {
  aqs_pm <- get_daily_aqs("pm25", "2025")
  expect_equal(names(aqs_pm), c("s2", "date", "pollutant", "conc"))
  expect_s3_class(aqs_pm, c("tbl_df", "tbl", "data.frame"))
})

test_that("get_aqs_data_mart_daily() works", {
  skip("takes too long and only use when not avail in datamart")
  d <- aqs_data_mart_daily("2025")
  expect_true(all(
    sapply(d, httr2::resp_status) == 200L
  ))
})
