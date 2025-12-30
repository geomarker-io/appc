#' Install daily PM2.5 averages
#'
#' Daily data by state is downloaded from the AQS API and filtered/harmonized as
#' described in the details. Data from the EPA AQS API are updated more frequently compared
#' to the pre-generated daily average files used by `get_daily_aqs()`.
#'
#' Installing AQS data via the API requires a key associated with an email address.
#' Signup with the url putting in your email address; e.g.,
#' https://aqs.epa.gov/data/api/signup?email=my.email.address@emails.com
#' and look for an email with the key.
#' Save these credentials as environment variables (or in a `.env` file):
#' `AQS_DATA_MART_API_EMAIL` and `AQS_DATA_MART_API_KEY`
#' @param year character; calendar year of data to install
#' @param force_reinstall logical; download data from original source instead of reusing older downloads
#' @details
#' For PM2.5 (FRM, non-FRM, and speciation), data is filtered to only observations with
#' a sample duration of "24 HOURS".
#' All pollutants measurements are removed if the observation percent
#' for the sampling period is less than 75 or were indicated to be invalid.
#' When a pollutant is measured by more than one device on the same day at the same
#' s2 location, the average measurement is returned, ensuring unique measurements for each pollutant-location-day
#' @return a character string path to an AQS data RDS file
#' @export
#' @examples
#' # on 2025-07-22, 2025 data goes until the end of March 2025
#' \dontrun{
#' install_aqs("2025") |>
#'   readRDS()
#' }
install_aqs <- function(
  year = as.character(2025:2017),
  force_reinstall = FALSE
) {
  year <- rlang::arg_match(year)
  dest_file <- fs::path(
    tools::R_user_dir("appc", "data"),
    glue::glue("aqs_{year}.rds")
  )
  if (file.exists(dest_file) & !force_reinstall) {
    return(dest_file)
  }
  d <- aqs_data_mart_daily(year = year)
  out <- purrr::map_dfr(d, process_resp, .progress = "assembling state data")
  saveRDS(out, dest_file)
  return(dest_file)
}

check_aqs_data_mart_creds <- function() {
  if (file.exists(".env")) {
    dotenv::load_dot_env()
    rlang::check_installed(
      "dotenv",
      "to read AQS Data Mart API credentials from the .env file"
    )
  }
  aqs_email <- Sys.getenv("AQS_DATA_MART_API_EMAIL")
  aqs_key <- Sys.getenv("AQS_DATA_MART_API_KEY")
  stopifnot(
    "environment variable AQS_DATA_MART_API_EMAIL must be set" = nzchar(
      aqs_email
    ),
    "environment variable AQS_DATA_MART_API_KEY must be set" = nzchar(aqs_key)
  )
  return(list(email = aqs_email, key = aqs_key))
}

aqs_data_mart_daily <- function(year) {
  aqs_creds <- check_aqs_data_mart_creds()
  the_req <-
    httr2::request("https://aqs.epa.gov/data/api/dailyData/byState") |>
    httr2::req_url_query(
      email = aqs_creds$email,
      key = aqs_creds$key,
      param = "88101",
      bdate = paste0(year, "0101"),
      edate = paste0(year, "1231")
    ) |>
    httr2::req_throttle(capacity = 1, fill_time_s = 5)
  the_states <- sprintf("%02d", c(1, 4:6, 8:13, 17:37, 39:42, 44:51, 53:56))
  the_reqs <- lapply(the_states, \(x) httr2::req_url_query(the_req, state = x))
  message("getting daily AQS data by state for ", year)
  the_resps <- httr2::req_perform_sequential(the_reqs)
  return(the_resps)
}

process_resp <- function(x) {
  rb <- httr2::resp_body_json(x)
  if (rb$Header[[1]]$status == "No data matched your selection") {
    return(NULL)
  }
  rb$Data |>
    dplyr::bind_rows() |>
    dplyr::filter(
      sample_duration == "24 HOUR",
      observation_percent >= 75,
      validity_indicator == "Y"
    ) |>
    dplyr::mutate(
      site = paste(state_code, county_code, site_number, sep = "-"),
      lat = latitude,
      lon = longitude,
      conc = arithmetic_mean,
      date = as.Date(date_local),
      .keep = "none"
    ) |>
    dplyr::mutate(s2 = s2::as_s2_cell(s2::s2_geog_point(lon, lat))) |>
    dplyr::summarise(conc = mean(conc, na.rm = TRUE), .by = c(s2, date))
}
