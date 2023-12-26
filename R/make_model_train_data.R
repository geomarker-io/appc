library(dplyr, warn.conflicts = FALSE)
library(s2)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(pollutant, date = dates, conc, s2)

d <-
  paste0("data/", c("elevation", "traffic", "nlcd", "nei"), ".rds") |>
  purrr::map(readRDS) |>
  purrr::reduce(left_join, by = "s2", .init = d)

# TODO pick the right annual vintages for predictors for each date

arrow::read_parquet("data/nlcd.parquet")

d_nei <- readRDS("data/nei.rds")

# TODO saving the years as the names of a list object do not get saved with parquet?
# use rds files instead?
dplyr::left_join(d, d_nei, by = "s2")$nei_point_id2w_1000

d <- d |>
  mutate(x = s2_x(s2_cell_to_lnglat(s2)),
         y = s2_y(s2_cell_to_lnglat(s2)))

d <-
  d |>
  tidyr::unnest(c(date, conc)) |>
  dplyr::mutate(year = format(date, "%Y"))

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
