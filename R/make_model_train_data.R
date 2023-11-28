library(dplyr, warn.conflicts = FALSE)
library(s2)

# TODO join in NEI data

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(pollutant, dates, conc, s2)

d_narr <-
  arrow::read_parquet("data/narr.parquet") |>
  select(s2, pollutant, air.2m, hpbl, acpcp, rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m)

d <- left_join(d, d_narr, by = c("s2", "pollutant"))

d_nlcd <-
  arrow::read_parquet("data/nlcd.parquet") |>
  select(pollutant, s2, pct_treecanopy, pct_imperviousness)

d <- left_join(d, d_nlcd, by = c("s2", "pollutant"))

d <- d |>
  mutate(pct_treecanopy = round(purrr::map_dbl(pct_treecanopy, 4)), # e.g., 2019
         pct_imperviousness = round(purrr::map_dbl(pct_imperviousness, 1))) # e.g., 2019

d_elevation <- arrow::read_parquet("data/elevation.parquet")

d <- left_join(d, d_elevation, by = "s2", relationship = "many-to-many")

d_5072_coords <-
  d |>
  mutate(
    lat = as.matrix(s2_cell_to_lnglat(s2))[, "y"],
    lon = as.matrix(s2_cell_to_lnglat(s2))[, "x"]
  ) |>
  terra::vect(crs = "epsg:4326") |>
  terra::project("epsg:5072") |>
  terra::crds()

d$x <- d_5072_coords[ , "x"]
d$y <- d_5072_coords[ , "y"]

d_train <-
  d |>
  tidyr::unnest(c(dates, conc, air.2m, hpbl, acpcp, rhum.2m,
                  vis, pres.sfc, uwnd.10m, vwnd.10m))

d_train$year <- as.numeric(format(d_train$dates, "%Y"))
d_train$doy <- as.numeric(format(d_train$dates, "%j"))

arrow::write_parquet(d_train, "data/train.parquet")
