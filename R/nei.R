#' installs NEI point data into user's data directory for the `appc` package
#' @param year a character string that is the year of the data
#' @return path to NEI point data parquet file
#' @details The NEI file is downloaded, unzipped, and filtered to observations
#' with a pollutant code of `EC`, `OC`, `SO4`, `NO3`, `PMFINE`, or `PM25-PRI`.
#' Latitude and longitude are encoded as an s2 vector, column names are cleaned,
#' and rows with missing values (including total emissions or emissions units) are excluded.
#' @export
install_nei_point_data <- function(year = as.character(c(2020, 2017))) {
  year <- rlang::arg_match(year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("nei_{year}.parquet"))
  if (file.exists(dest_file)) return(dest_file)
  message(glue::glue("downloading {year} NEI file"))
  zip_path <- fs::path(tempdir(), glue::glue("nei_{year}.zip"))
  dplyr::case_when(year == "2020" ~ "https://gaftp.epa.gov/air/nei/2020/data_summaries/Facility%20Level%20by%20Pollutant.zip",
                   year == "2017" ~ "https://gaftp.epa.gov/air/nei/2017/data_summaries/2017v1/2017neiJan_facility.zip") |>
    httr::GET(httr::write_disk(zip_path), httr::progress(), overwrite = TRUE)
  nei_raw_paths <- utils::unzip(zip_path, exdir = tempdir())
  grep(".csv", nei_raw_paths, fixed = TRUE, value = TRUE) |>
    readr::read_csv(col_types = readr::cols_only(
      `site latitude` = readr::col_double(),
      `site longitude` = readr::col_double(),
      `pollutant code` = readr::col_character(),
      `total emissions` = readr::col_double(),
      `emissions uom` = readr::col_character()
    )) |>
    dplyr::filter(`pollutant code` %in%
                    c("EC", "OC", "SO4", "NO3", "PMFINE", "PM25-PRI")) |>
    dplyr::mutate(s2 = s2::as_s2_cell(s2::s2_geog_point(`site longitude`, `site latitude`))) |>
    dplyr::select(-`site latitude`, -`site longitude`) |>
    dplyr::rename_with(~ tolower(gsub(" ", "_", .x, fixed = TRUE))) |>
    stats::na.omit() |>
    arrow::write_parquet(dest_file)
  return(dest_file)
}

utils::globalVariables(c("pollutant code", "site longitude", "site latitude", "total_emissions"))

#' get NEI point summary data
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param year a character string that is the year of the NEI data
#' @param pollutant_code the NEI pollutant to summarize
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return a vector (the same length as `x`) of the sum of all point emissions within the buffer distance weighted
#' by the inverse of the distance squared to each emission point
#' @export
get_nei_point_summary <- function(x, year, pollutant_code = c("PM25-PRI", "EC", "OC", "SO4", "NO3", "PMFINE"), buffer = 1000) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  nei_data <- arrow::read_parquet(install_nei_point_data(year = year))
  pollutant_code <- rlang::arg_match(pollutant_code)
  message("intersecting ", year, " ", pollutant_code, " NEI point sources within ", buffer, " meters")
  withins <- s2::s2_dwithin_matrix(s2::s2_cell_to_lnglat(x), s2::s2_cell_to_lnglat(nei_data$s2), distance = buffer)
  summarize_emissions <- function(i) {
    nei_data[withins[[i]], ] |>
      dplyr::filter(pollutant_code == pollutant_code) |>
      dplyr::mutate(
        dist_to_point =
          purrr::map_dbl(s2, \(.) s2::s2_cell_distance(., x[[i]]))
      ) |>
      dplyr::summarize(nei_pm25_id2w = sum(total_emissions / dist_to_point^2)) |>
      as.double()
  }
  nei_pollutant_id2w <- purrr::map_dbl(1:length(withins), summarize_emissions, .progress = "summarizing intersections")
  return(nei_pollutant_id2w)
}

utils::globalVariables(c("dist_to_point"))
