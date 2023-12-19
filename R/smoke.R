library(dplyr)

# from: https://github.com/echolab-stanford/daily-10km-smokePM and
# https://pubmed.ncbi.nlm.nih.gov/36134580/
# accessed on 2023-08-02
# note that any census tract - date combination implicitly missing has a value of zero
download_smoke_pm <- function(){
  smoke_file_path <- "data-raw/smoke.parquet"
  if (file.exists(smoke_file_path)) {
    return(smoke_file_path)
  }
  tf <- tempfile()
  httr::GET("https://www.dropbox.com/sh/atmtfc54zuknnob/AAA7AVRQP-GoIMHpxlvfN7RBa?dl=1",
            httr::write_disk(tf),
            httr::progress())
  d_smoke <-
    unz(tf, grep(".csv", unzip(tf, list = TRUE)$Name, value = TRUE)) |>
    readr::read_csv(
      col_types = list("GEOID" = readr::col_character(),
                       "date" = readr::col_date(format = "%Y%m%d"),
                       "smokePM_pred" = readr::col_double())) |>
    rename(census_tract_id_2010 = GEOID,
           smoke_pm = smokePM_pred) |>
    filter(date > as.Date("2015-12-31"))
  arrow::write_parquet(d_smoke, smoke_file_path)
  return(smoke_file_path)
}

d_smoke <- arrow::read_parquet(download_smoke_pm())

d_tract <- arrow::read_parquet("data/tract.parquet")

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  tidyr::unnest(cols = c(dates, conc)) |>
  rename(date = dates) |>
  distinct(s2, date) |>
  left_join(d_tract, by = "s2")

left_join(d, d_smoke, by = c("census_tract_id_2010", "date")) |>
  tidyr::replace_na(list(smoke_pm = 0)) |>
  arrow::write_parquet("data/smoke.parquet")
