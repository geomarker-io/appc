library(dplyr, warn.conflicts = FALSE)
library(s2)
library(purrr)

d <-
  readRDS("data/aqs.rds") |>
  select(pollutant, date = dates, conc, s2)

d <- d |>
  mutate(x = s2_x(s2_cell_to_lnglat(s2)),
         y = s2_y(s2_cell_to_lnglat(s2)))

d <-
  paste0("data/", c("elevation", "traffic", "nlcd", "nei"), ".rds") |>
  map(readRDS) |>
  reduce(left_join, by = "s2", .init = d)

get_closest_year <- function(date, years) {
  date_year <- as.numeric(format(date, "%Y"))
  map_chr(date_year, \(x) years[which.min(abs(as.numeric(years) - x))])
}

d$treecanopy_400 <- map2(d$date, d$treecanopy_400, \(x, y) y[get_closest_year(date = x, years = names(y[1]))], .progress = "matching annual treecanopy")
d$impervious_400 <- map2(d$date, d$impervious_400, \(x, y) y[get_closest_year(date = x, years = names(y[1]))], .progress = "matching annual impervious")
d$nei_point_id2w_1000 <- map2(d$date, d$nei_point_id2w_1000, \(x, y) y[get_closest_year(date = x, years = names(y[1]))], .progress = "matching annual NEI")


d <- d |> tidyr::unnest(c(date, conc, impervious_400, treecanopy_400, nei_point_id2w_1000))

d_narr <-
  readRDS("data/narr.rds") |>
  rename(date = dates) |>
  tidyr::unnest(c(date, air.2m, hpbl, acpcp, rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m))

d <- left_join(d, d_narr, by = c("s2", "date"), relationship = "many-to-many")

d <- left_join(d, readRDS("data/smoke.rds"), by = c("s2", "date"), relationship = "many-to-many")

d$year <- as.numeric(format(d$date, "%Y"))
d$doy <- as.numeric(format(d$date, "%j"))

saveRDS(d, "data/train.rds")
