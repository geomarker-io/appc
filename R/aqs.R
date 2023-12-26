library(dplyr, warn.conflicts = FALSE)
library(tidyr)
library(s2)

# get all the files on the page and the date they were last updated:
## readr::read_csv("https://aqs.epa.gov/aqsweb/airdata/file_list.csv")

#' Get daily AQS concentrations
#'
#' Pre-generated daily summary files are downloaded from the EPA AQS website
#' and filtered/harmonized as described in the Details.
#' @param pollutant one of "pm25", "ozone", or "no2"
#' @param year calendar year
#' @return data.frame/tibble of pollutant concentrations with site id, lat/lon, and date
#' @details
#' For PM2.5 (FRM, non-FRM, and speciation), data is filtered to only observations with
#' a sample duration of "24 HOURS".
#' All pollutants measurements are removed if the observation percent
#' for the sampling period is less than 75.
#' When a pollutant is measured by more than one device on the same day at the same
#' s2 location, the average measurement is returned, ensuring unique measurements for each pollutant-location-day
#'
#' Note: Historical measurements are subject to change and the EPA AQS website only stores
#' the latest versions.  Since this function always downloads the latest data from EPA AQS,
#' that means that it will could different results depending on the date it was run.
#' @examples
#' get_daily_aqs("pm25", "2021")
#' get_daily_aqs("ozone", "2021")
#' get_daily_aqs("no2", "2021")
#' @export
get_daily_aqs <- function(pollutant, year = "2021") {
  stopifnot(pollutant %in% c("pm25", "ozone", "no2"))
  pollutant_code <-
    c(
      "pm25" = "88101",
      "ozone" = "44201",
      "no2" = "42602"
    )[pollutant]
  file_name <- glue::glue("daily_{pollutant_code}_{year}.zip")
  on.exit(unlink(file_name))
  download.file(
    url = glue::glue("https://aqs.epa.gov/aqsweb/airdata/{file_name}"),
    destfile = file_name,
    quiet = TRUE
  )
  unzipped_file_name <- gsub(pattern = ".zip", ".csv", file_name, fixed = TRUE)
  on.exit(unlink(unzipped_file_name), add = TRUE)
  unzip(file_name)
  d_in <- readr::read_csv(unzipped_file_name, show_col_types = FALSE)
  if (pollutant_code %in% c("88101", "88502")) {
    d_in <- filter(d_in, `Sample Duration` == "24 HOUR")
  }
  d_out <-
    d_in |>
    filter(`Observation Percent` >= 75) |>
    transmute(
      site = paste(`State Code`, `County Code`, `Site Num`, sep = "-"),
      lat = Latitude,
      lon = Longitude,
      conc = `Arithmetic Mean`,
      date = `Date Local`,
      pollutant = pollutant
    ) |>
    mutate(s2 = as_s2_cell(s2_geog_point(lon, lat))) |>
    group_by(s2, date, pollutant) |>
    summarise(conc = mean(conc, na.rm = TRUE), .groups = "drop")
  return(d_out)
}

d <-
  tidyr::expand_grid(
    pollutant = c("pm25", "ozone", "no2"),
    year = 2016:2022
  ) |>
  purrr::pmap(get_daily_aqs, .progress = "getting daily AQS data")

aqs <-
  d |>
  purrr::list_rbind() |>
  mutate(across(c(pollutant), as.factor)) |>
  nest_by(s2, pollutant) |>
  ungroup()

aqs <-
  aqs |>
  mutate(
    dates = purrr::map(aqs$data, "date"),
    conc = purrr::map(aqs$data, "conc")
  ) |>
  select(-data) |>
  mutate(s2_geometry = as_s2_geography(s2_cell_to_lnglat(s2)))

us <-
  tigris::states(year = 2020) |>
  filter(!NAME %in% c(
    "United States Virgin Islands",
    "Guam", "Commonwealth of the Northern Mariana Islands",
    "American Samoa", "Puerto Rico",
    "Alaska", "Hawaii"
  )) |>
  sf::st_as_s2() |>
  s2_union_agg()

aqs <-
  aqs |>
  filter(s2_intersects(s2_geometry, us)) |>
  select(-s2_geometry)

dir.create("data", showWarnings = FALSE)
saveRDS(aqs, "data/aqs.rds")
