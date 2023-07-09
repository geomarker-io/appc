library(dplyr)
library(tidyr)
library(sf)

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
#' When a pollutant is measured by more than one device at the same site, the average measurement
#' is returned, ensuring unique measurements for each pollutant-location-day.
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
  on.exit(unlink(unzipped_file_name))
  unzip(file_name)
  d_in <- readr::read_csv(unzipped_file_name, show_col_types = FALSE)
  if (pollutant_code %in% c("88101", "88502")) {
    d_in <- filter(d_in, `Sample Duration` == "24 HOUR")
  }
  d_out <-
    d_in |>
    filter(`Observation Percent` >= 75) |>
    transmute(
      ## id = paste(`State Code`, `County Code`, `Site Num`, sep = "-"),
      state = `State Code`,
      county = `County Code`,
      site = `Site Num`,
      lat = Latitude,
      lon = Longitude,
      conc = `Arithmetic Mean`,
      date = `Date Local`,
      pollutant = pollutant
    ) |>
    group_by(state, county, site, lat, lon, date, pollutant) |>
    summarise(conc = mean(conc, na.rm = TRUE), .groups = "drop")
  return(d_out)
}

d <-
  tidyr::expand_grid(
    pollutant = c("pm25", "ozone", "no2"),
    year = 2000:{as.integer(format(Sys.Date(), "%Y")) - 1}
  ) |>
  purrr::pmap(get_daily_aqs, .progress = "getting daily AQS data")

library(s2)
sf_use_s2(TRUE)

aqs <-
  d |>
  purrr::list_rbind() |>
  mutate(across(c(state, county, site, pollutant), as.factor)) |>
  nest_by(state, county, site, lat, lon, pollutant) |>
  ungroup() |>
  mutate(geography = s2_geog_point(lon, lat))

aqs <-
  aqs |>
  mutate(
    dates = purrr::map(aqs$data, "date"),
    conc = purrr::map(aqs$data, "conc")
  ) |>
  select(-data)
    
us <-
  tigris::states(year = 2020) |>
  filter(!NAME %in% c(
    "United States Virgin Islands",
    "Guam", "Commonwealth of the Northern Mariana Islands",
    "American Samoa", "Puerto Rico",
    "Alaska", "Hawaii"
  )) |>
  st_as_s2() |>
  s2::s2_union_agg()

aqs <- aqs[s2_intersects(aqs$geography, us), ]

aqs <-
  aqs |>
  mutate(s2 = as_s2_cell(geography)) |>
  select(-geography)

dir.create("data", showWarnings = FALSE)
arrow::write_parquet(aqs, "data/aqs.parquet")
