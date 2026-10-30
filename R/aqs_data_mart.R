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
#'
#' Interrupted refreshes retain harmonized state extracts in an
#' `aqs_<year>_partial` directory under the appc data directory. Retrying the
#' refresh reuses completed states. These temporary checkpoints are removed
#' after the complete annual extract is saved successfully. Requests retry
#' interrupted connections and transient server errors for up to four attempts.
#' @return a character string path to an AQS data RDS file
#' @export
#' @examples
#' # Data Mart data can be more current than the bulk AQS daily files.
#' \dontrun{
#' install_aqs("2026") |>
#'   readRDS()
#' }
install_aqs <- function(
  year = as.character(2026:2017),
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
  requests <- aqs_data_mart_requests(year)
  checkpoint_dir <- fs::path(
    tools::R_user_dir("appc", "data"),
    glue::glue("aqs_{year}_partial")
  )
  fs::dir_create(checkpoint_dir)
  message("getting daily AQS data by state for ", year)
  out <- purrr::imap(
    requests,
    function(req, state) {
      path <- fs::path(checkpoint_dir, paste0(state, ".rds"))
      if (file.exists(path)) {
        message("reusing completed AQS state ", state)
        return(readRDS(path))
      }
      message("retrieving AQS state ", state)
      data <- process_resp(httr2::req_perform(req))
      aqs_save_rds(data, path)
      data
    },
    .progress = "assembling state data"
  ) |>
    dplyr::bind_rows()
  aqs_save_rds(out, dest_file)
  # Only remove this refresh's redundant state checkpoints after saving all rows.
  unlink(fs::path(checkpoint_dir, paste0(names(requests), ".rds")))
  return(dest_file)
}

aqs_save_rds <- function(data, path) {
  staged <- tempfile("aqs-", tmpdir = fs::path_dir(path), fileext = ".rds")
  on.exit(unlink(staged), add = TRUE)
  saveRDS(data, staged)
  fs::file_move(staged, path)
  invisible(path)
}

aqs_data_mart_requests <- function(year) {
  aqs_creds <- needenv::needenv(AQS_DATA_MART_API_EMAIL, AQS_DATA_MART_API_KEY)
  the_req <-
    httr2::request("https://aqs.epa.gov/data/api/dailyData/byState") |>
    httr2::req_url_query(
      email = aqs_creds$AQS_DATA_MART_API_EMAIL,
      key = aqs_creds$AQS_DATA_MART_API_KEY,
      param = "88101",
      bdate = paste0(year, "0101"),
      edate = paste0(year, "1231")
    ) |>
    httr2::req_throttle(capacity = 1, fill_time_s = 5) |>
    httr2::req_retry(
      max_tries = 4,
      retry_on_failure = TRUE,
      is_transient = function(resp) {
        httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
      }
    )
  the_states <- sprintf("%02d", c(1, 4:6, 8:13, 16:42, 44:51, 53:56))
  the_reqs <- lapply(the_states, \(x) httr2::req_url_query(the_req, state = x))
  stats::setNames(the_reqs, the_states)
}

aqs_data_mart_daily <- function(year) {
  the_reqs <- aqs_data_mart_requests(year)
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
