library(dplyr)
library(s2)
library(readr)


# TODO update to get every three years release
make_nei_data <- function() {
  # TODO automate 'pinning' downloaded data
  ## download.file("https://gaftp.epa.gov/air/nei/2020/data_summaries/Facility%20Level%20by%20Pollutant.zip",
  ##   destfile = "data-raw/nei_2020.zip"
  ## )
  ## unzip("data-raw/2020_nei.zip")
  read_csv("data-raw/Facility Level by Pollutant/emis_sum_fac_23959.csv",
    col_types = cols_only(
      `site latitude` = col_double(),
      `site longitude` = col_double(),
      `pollutant code` = col_character(),
      `total emissions` = col_double(),
      `emissions uom` = col_character(),
    )
  ) |>
    filter(`pollutant code` %in%
      c("EC", "OC", "SO4", "NO3", "PMFINE", "PM25-PRI")) |>
    mutate(s2 = as_s2_cell(s2_geog_point(`site longitude`, `site latitude`))) |>
    select(-`site latitude`, -`site longitude`) |>
    rename_with(~ tolower(gsub(" ", "_", .x, fixed = TRUE))) |>
    na.omit()
}

d_nei <- make_nei_data()

d <- arrow::read_parquet("data/aqs.parquet")

message("intersecting nei point sources")
d$withins <- s2_dwithin_matrix(s2_cell_to_lnglat(d$s2), s2_cell_to_lnglat(d_nei$s2), distance = 1000)

summarize_emissions <- function(i) {
  d_nei[d$withins[[i]], ] |>
    filter(pollutant_code == "PM25-PRI") |>
    mutate(
      dist_to_point =
        purrr::map_dbl(s2, \(.) s2_cell_distance(., d$s2[[i]]))
    ) |>
    summarize(nei_pm25_id2w = sum(total_emissions / dist_to_point^2)) |>
    as.double()
}

d$nei_pm25_id2w <- purrr::map_dbl(1:nrow(d), summarize_emissions, .progress = "summarizing intersected nei point sources")

# TODO add non-point sources

d |>
  select(s2, pollutant, nei_pm25_id2w) |>
  arrow::write_parquet("data/nei.parquet")
