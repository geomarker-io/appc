#' installs smoke pm data into user's data directory for the `appc` package
#' 
#' note that any census tract - date combination implicitly missing has a value of zero
#' @references https://github.com/echolab-stanford/daily-10km-smokePM and https://pubmed.ncbi.nlm.nih.gov/36134580/
#' @return path to elevation raster
install_smoke_pm_data <- function() {
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), "smoke.parquet")
  if (file.exists(dest_file)) return(dest_file)
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
  arrow::write_parquet(d_smoke, dest_file)
  return(dest_file)
}


library(dplyr)

d_tract <- arrow::read_parquet("data/tract.parquet")
d_smoke <- arrow::read_parquet(install_smoke_pm_data())

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  tidyr::unnest(cols = c(dates, conc)) |>
  rename(date = dates) |>
  distinct(s2, date) |>
  left_join(d_tract, by = "s2", relationship = "many-to-many")

left_join(d, d_smoke, by = c("census_tract_id_2010", "date")) |>
  tidyr::replace_na(list(smoke_pm = 0)) |>
  arrow::write_parquet("data/smoke.parquet")
