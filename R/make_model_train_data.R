library(dplyr, warn.conflicts = FALSE)
library(s2)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(pollutant, date = dates, conc, s2)

arrow::read_parquet("data/nei.parquet")
arrow::read_parquet("data/traffic.parquet")
arrow::read_parquet("data/nlcd.parquet")
arrow::read_parquet("data/elevation.parquet")

paste0("data/", c("nei", "traffic", "nlcd", "elevation"), ".parquet") |>
  purrr::map(arrow::read_parquet) |>
  purrr::reduce(left_join, by = "s2", .init = d)

# TODO pick the right annual vintages for predictors for each date


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
