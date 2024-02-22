library(dplyr, warn.conflicts = FALSE)
library(s2)
library(purrr)
library(tidyr)

# load development version if developing (instead of currently installed version)
if (file.exists("./inst")) {
  devtools::load_all()
} else {
  library(appc)
}

# get AQS data
d <-
  tidyr::expand_grid(
    ## pollutant = c("pm25", "ozone", "no2"),
    pollutant = "pm25",
    year = as.character(2017:2023)
  ) |>
  purrr::pmap(get_daily_aqs, .progress = "getting daily AQS data")

# structure for pipeline
d <-
  d |>
  list_rbind() |>
  mutate(across(c(pollutant), as.factor)) |>
  nest_by(s2, pollutant) |>
  ungroup() |>
  mutate(
    dates = purrr::map(data, "date"),
    conc = purrr::map(data, "conc")
  ) |>
  select(-data)

# subset to contiguous US
d <- d |>
  filter(
    s2_intersects(
      as_s2_geography(s2_cell_to_lnglat(s2)),
      contiguous_us()
    )
  )

d <- d |>
  mutate(x = s2_x(s2_cell_to_lnglat(s2)),
         y = s2_y(s2_cell_to_lnglat(s2)))

# elevation
d$elevation_median_800 <- get_elevation_summary(x = d$s2, fun = median, buffer = 800)
d$elevation_sd_800 <- get_elevation_summary(x = d$s2, fun = sd, buffer = 800)

# aadt
d$traffic_400 <- get_traffic_summary(d$s2, buffer = 400)
d$aadt_total_m_400 <- purrr::map_dbl(d$traffic_400, "aadt_total_m")
d$aadt_truck_m_400 <- purrr::map_dbl(d$traffic_400, "aadt_truck_m")
d$traffic_400 <- NULL

# narr
my_narr <- purrr::partial(get_narr_data, x = d$s2, dates = d$dates)
d$air.2m <- my_narr("air.2m")
d$hpbl <- my_narr("hpbl")
d$acpcp <- my_narr("acpcp")
d$rhum.2m <- my_narr("rhum.2m")
d$vis <- my_narr("vis")
d$pres.sfc <- my_narr("pres.sfc")
d$uwnd.10m <- my_narr("uwnd.10m")
d$vwnd.10m <- my_narr("vwnd.10m")

# merra
d$merra <- get_merra_data(d$s2, d$dates)
d$merra_dust <- purrr::map(d$merra, "merra_dust")
d$merra_oc <- purrr::map(d$merra, "merra_oc")
d$merra_bc <- purrr::map(d$merra, "merra_bc")
d$merra_ss <- purrr::map(d$merra, "merra_ss")
d$merra_so4 <- purrr::map(d$merra, "merra_so4")
d$merra_pm25 <- purrr::map(d$merra, "merra_pm25")
d$merra <- NULL

# urban imperviousness
impervious_years <- c("2016", "2019", "2021")
d$urban_imperviousness_400 <-
  purrr::map(impervious_years, \(x) get_urban_imperviousness(d$s2, year = x, buffer = 400)) |>
  setNames(impervious_years) |>
  purrr::list_transpose()
d$urban_imperviousness_400 <- purrr::map2(d$dates, d$urban_imperviousness_400, \(x, y) y[get_closest_year(x = x, years = names(y[1]))], .progress = "matching annual impervious")

# nei
nei_years <- c("2017", "2020")
d$nei_point_id2w_1000 <-
  purrr::map(nei_years, \(x) get_nei_point_summary(d$s2, year = x, pollutant_code = "PM25-PRI", buffer = 1000)) |>
  setNames(nei_years) |>
  purrr::list_transpose()
d$nei_point_id2w_1000 <- map2(d$dates, d$nei_point_id2w_1000, \(x, y) y[get_closest_year(x = x, years = names(y[1]))], .progress = "matching annual NEI")

# unnest
d <-
  d |>
  tidyr::unnest(cols = c(dates, conc, air.2m, hpbl, acpcp,
                         rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m,
                         merra_dust, merra_oc, merra_bc, merra_ss, merra_so4, merra_pm25,
                         urban_imperviousness_400,
                         nei_point_id2w_1000)) |>
  rename(date = dates)

# smoke
d$census_tract_id_2010 <- get_census_tract_id(d$s2, year = "2010")
d_smoke <- readRDS(install_smoke_pm_data())
d <-
  d |>
  left_join(d_smoke, by = c("census_tract_id_2010", "date")) |>
  tidyr::replace_na(list(smoke_pm = 0)) |>
  select(-census_tract_id_2010)

d$year <- as.numeric(format(d$date, "%Y"))
d$doy <- as.numeric(format(d$date, "%j"))
d$month <- as.numeric(format(d$date, "%m"))

saveRDS(d, fs::path_wd("training_data.rds"))
