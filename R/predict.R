.appc_cache <- new.env(parent = emptyenv())

load_rf_pm_model <- function(model_version = "0") {
  st <- Sys.time()
  if (is.null(.appc_cache$model)) {
    grf_file <- fs::path(
      tools::R_user_dir("appc", "data"),
      glue::glue("rf_pm_v{model_version}.qs")
    )
    if (!file.exists(grf_file)) {
      message("downloading rf_pm_v", model_version)
      utils::download.file(
        glue::glue(
          "https://github.com",
          "geomarker-io",
          "appc",
          "releases",
          "download",
          "rf_pm_v{model_version}",
          "rf_pm_v{model_version}.qs",
          .sep = "/"
        ),
        grf_file,
        quiet = FALSE,
        mode = "wb"
      )
    }
    .appc_cache$model <- qs::qread(grf_file)
  }
  et <- Sys.time()
  message(
    "loaded rf_pm_v",
    model_version,
    " in ",
    as.integer(difftime(et, st, units = "secs")),
    "s"
  )
  return(.appc_cache$model)
}

#' Get daily PM2.5 model predictions
#'
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a list of date vectors for the predictions, must be the same length as `x`
#' @return a list of tibbles the same length as `x`, each containing
#' columns for the predicted (`pm25`) and its standard error (`pm25_se`);
#' with one row per date in `dates`. These numerics are the concentrations of fine
#' particulate matter, measured in micrograms per cubic meter. See `vignette("cv-model-performance")`
#' for more details on the cross validated accuracy of the daily PM2.5 model predictions.
#' @details
#' Internally, loading the model file is cached, so repeated calls in the same R session
#' will not require the overhead of loading the model file for a new prediction.
#' @export
#' @examples
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
#'   "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
#' )
#'
#' predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)
#'
#' # takes less time after called once because model file is cached in memory
#'
#' d <- list(
#'   "8841b39a7c46e25f" = as.Date(c("2023-05-13", "2023-11-16")),
#'   "8841a45555555555" = as.Date(c("2023-06-21", "2023-08-25"))
#' )
#' predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)
predict_pm25 <- function(x, dates) {
  check_s2_dates(x, dates)
  cli::cli_progress_step("(down)loading random forest model")
  grf <- load_rf_pm_model()
  cli::cli_progress_done()
  required_predictors <- names(grf$X.orig)
  d <- assemble_predictors(x = x, dates = dates, pollutant = "pm25")
  stopifnot(all(required_predictors %in% names(d)))
  stopifnot(inherits(grf, "regression_forest"))
  foofy <- grf::regression_forest
  d_pred <-
    stats::predict(
      grf,
      dplyr::select(d, dplyr::all_of(required_predictors)),
      estimate.variance = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::transmute(
      pm25 = predictions,
      pm25_se = sqrt(variance.estimates)
    )

  d_pred$.rowid <- rep(seq_along(x), times = sapply(dates, length))

  out <-
    d_pred |>
    dplyr::nest_by(.rowid) |>
    tibble::deframe() |>
    as.list()
  names(out) <- NULL

  return(out)
}

#' Get daily PM2.5 model predictions using date ranges
#'
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param start_date a date vector of start dates for each s2 cell, must be the same length as `x`
#' @param end_date a date vector of end dates for each s2 cell, must be the same length as `x`
#' @param average logical; summarize daily exposures estimates and standard errors?
#' @details
#' The standard error for averages of daily pm25 exposures with known standard errors
#' is calculated, assuming they are independent, as the square root of the sum of squared
#' individual standard errors divided the total number of individual daily pm25 exposures.
#' @export
#' @examples
#' predict_pm25_date_range(
#'   x = c("8841b39a7c46e25f", "8841a45555555555"),
#'   start_date = as.Date(c("2023-05-18", "2023-01-06")),
#'   end_date = as.Date(c("2023-06-22", "2023-08-15")),
#'   average = TRUE
#' )
predict_pm25_date_range <- function(x, start_date, end_date, average = FALSE) {
  x <- s2::as_s2_cell(x)
  stopifnot(length(start_date) == length(end_date))
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)
  stopifnot(length(x) == length(start_date))
  stopifnot(all(start_date < end_date))
  dates <- purrr::map2(
    start_date,
    end_date,
    \(.sd, .ed) seq.Date(from = .sd, to = .ed, by = "day")
  )
  preds <- predict_pm25(x = x, dates = dates)
  if (average) {
    preds <- purrr::modify(preds, \(.x) {
      tibble::tibble(
        pm25 = mean(.x$pm25),
        pm25_se = sqrt(sum(.x$pm25_se^2)) / nrow(.x)
      )
    })
  }
  return(preds)
}
