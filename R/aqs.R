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
#' Similarly, the most recent year might not contain measurements for the entire calendar year.
#'
#' Get all the files on the page and the date they were last updated:
#' `readr::read_csv("https://aqs.epa.gov/aqsweb/airdata/file_list.csv")`
#' @examples
#' get_daily_aqs("pm25", "2024")
#' get_daily_aqs("pm25", "2020")
#' @export
get_daily_aqs <- function(
  pollutant = c("pm25", "ozone", "no2"),
  year = as.character(2017:2025)
) {
  rlang::check_installed("readr", "to read daily AQS CSV files from the EPA.")
  pollutant <- rlang::arg_match(pollutant)
  year <- rlang::arg_match(year)
  pollutant_code <-
    c(
      "pm25" = "88101",
      "ozone" = "44201",
      "no2" = "42602"
    )[pollutant]
  tf <- tempfile()
  utils::download.file(
    glue::glue(
      "https://aqs.epa.gov/aqsweb/airdata/daily_{pollutant_code}_{year}.zip"
    ),
    tf
  )
  the_files <- utils::unzip(tf, list = TRUE)$Name
  first_csv_file <- grep(
    "\\.csv$",
    the_files,
    ignore.case = TRUE,
    value = TRUE
  )[[1]]
  stopifnot(
    "did not find a single CSV file in AQS download" = length(first_csv_file) ==
      1
  )

  d_in <- readr::read_csv(unz(tf, first_csv_file), show_col_types = FALSE)
  if (pollutant_code %in% c("88101", "88502")) {
    d_in <- dplyr::filter(d_in, `Sample Duration` == "24 HOUR")
  }
  if (pollutant == "pm25" && year == "2020") {
    d_in$`Date Local` <- as.Date(d_in$`Date Local`, format = "%m/%d/%Y")
  }
  d_out <-
    d_in |>
    dplyr::filter(`Observation Percent` >= 75) |>
    dplyr::transmute(
      site = paste(`State Code`, `County Code`, `Site Num`, sep = "-"),
      lat = Latitude,
      lon = Longitude,
      conc = `Arithmetic Mean`,
      date = as.Date(`Date Local`),
      pollutant = pollutant
    ) |>
    dplyr::mutate(s2 = s2::as_s2_cell(s2::s2_geog_point(lon, lat))) |>
    dplyr::group_by(s2, date, pollutant) |>
    dplyr::summarise(conc = mean(conc, na.rm = TRUE), .groups = "drop")
  return(d_out)
}
