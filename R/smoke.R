#' Installs daily, census-tract level smoke pm data into user's data directory for the `appc` package
#'
#' See the examples to read the installed parquet file.
#' Merge this data with existing data on `date` and `census_tract_id_2010` to retrieve the
#' `smoke_pm` column. Note that any census tract-date combination implicitly missing has a value of zero.
#' @references <https://pubmed.ncbi.nlm.nih.gov/36134580/>
#' @references <https://github.com/echolab-stanford/daily-10km-smokePM>
#' @return path to parquet file containing smoke data
#' @export
#' @examples
#' \dontrun{
#' arrow::read_parquet(install_smoke_pm_data())
#' }
install_smoke_pm_data <- function() {
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), "smoke.parquet")
  if (file.exists(dest_file)) {
    return(as.character(dest_file))
  }
  if (!install_source_preference()) {
    install_released_data(released_data_name = "smoke.parquet")
    return(as.character(dest_file))
  }
  message("downloading and installing smoke PM data from source")
  tf <- tempfile()
  utils::download.file("https://www.dropbox.com/sh/atmtfc54zuknnob/AAA7AVRQP-GoIMHpxlvfN7RBa?dl=1", tf)
  d_smoke <-
    unz(tf, grep(".csv", utils::unzip(tf, list = TRUE)$Name, value = TRUE)) |>
    readr::read_csv(
      col_types = list(
        "GEOID" = readr::col_character(),
        "date" = readr::col_date(format = "%Y%m%d"),
        "smokePM_pred" = readr::col_double()
      )
    ) |>
    dplyr::rename(
      census_tract_id_2010 = GEOID,
      smoke_pm = smokePM_pred
    ) |>
    dplyr::filter(date > as.Date("2015-12-31"))
  arrow::write_parquet(d_smoke, dest_file)
  return(as.character(dest_file))
}

utils::globalVariables(c("GEOID", "smokePM_pred"))
