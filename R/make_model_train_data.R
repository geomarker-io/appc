library(dplyr, warn.conflicts = FALSE)
library(s2)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(pollutant, date = dates, conc, s2)

d_nei <-
  arrow::read_parquet("data/nei.parquet")

d <- left_join(d, d_nei, by = c("s2", "pollutant"))

d_aadt <-
  arrow::read_parquet("data/traffic.parquet")

d <- left_join(d, d_aadt, by = c("s2", "pollutant"))

d_nlcd <-
  arrow::read_parquet("data/nlcd.parquet") |>
  select(pollutant, s2, pct_treecanopy, pct_imperviousness)

d <- left_join(d, d_nlcd, by = c("s2", "pollutant"))

# TODO choose years in nlcd data based on calendar year; right now, see examples below for 2019
d <- d |>
  mutate(pct_treecanopy = round(purrr::map_dbl(pct_treecanopy, \(.) purrr::pluck(., 4, .default = NA))), # e.g., 2019
         pct_imperviousness = round(purrr::map_dbl(pct_imperviousness, \(.) purrr::pluck(., 1, .default = NA)))) # e.g., 2019

d_elevation <- arrow::read_parquet("data/elevation.parquet")

d <- left_join(d, d_elevation, by = "s2", relationship = "many-to-many")

d <- d |>
  mutate(x = s2_x(s2_cell_to_lnglat(s2)),
         y = s2_y(s2_cell_to_lnglat(s2)))

d <- d |> tidyr::unnest(c(date, conc))

d_narr <-
  arrow::read_parquet("data/narr.parquet") |>
  select(s2, date = dates, pollutant, air.2m, hpbl, acpcp, rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m) |>
  tidyr::unnest(c(date, air.2m, hpbl, acpcp, rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m))

d <- left_join(d, d_narr, by = c("s2", "date", "pollutant"))

d_smoke <-
  arrow::read_parquet("data/smoke.parquet") |>
  select(-census_tract_id_2010)

d <- left_join(d, d_smoke, by = c("s2", "date"))

d$year <- as.numeric(format(d$date, "%Y"))
d$doy <- as.numeric(format(d$date, "%j"))

arrow::write_parquet(d, "data/train.parquet")
