.appc_cache <- new.env(parent = emptyenv())

.rf_pm_model_checksums <- list(
  "2" = c(
    sha256 = "f0a772b99544c441ff4034f9d2a334b88466413d977e57a8bb96bac3df8f5197",
    md5 = "921f0300bcdec0eed151d14f03a6f727"
  )
)

rf_pm_model_checksum_matches <- function(path, checksums) {
  if (is.null(checksums)) {
    return(TRUE)
  }

  sha256sum <- get0(
    "sha256sum",
    envir = asNamespace("tools"),
    inherits = FALSE
  )
  if (!is.null(sha256sum)) {
    actual <- unname(sha256sum(path))
    expected <- unname(checksums[["sha256"]])
  } else {
    actual <- unname(tools::md5sum(path))
    expected <- unname(checksums[["md5"]])
  }

  identical(actual, expected)
}

download_rf_pm_model <- function(path, model_version, checksums) {
  fs::dir_create(fs::path_dir(path))
  download_path <- tempfile(
    pattern = paste0(fs::path_file(path), "-"),
    tmpdir = fs::path_dir(path)
  )
  on.exit(unlink(download_path), add = TRUE)

  message("downloading rf_pm_v", model_version)
  utils::download.file(
    glue::glue(
      "https://github.com",
      "geomarker-io",
      "appc",
      "releases",
      "download",
      "rf_pm_v{model_version}",
      "rf_pm_v{model_version}.rds",
      .sep = "/"
    ),
    download_path,
    quiet = FALSE,
    mode = "wb"
  )

  if (!rf_pm_model_checksum_matches(download_path, checksums)) {
    stop(
      "downloaded rf_pm_v",
      model_version,
      " model failed checksum verification",
      call. = FALSE
    )
  }
  if (!file.rename(download_path, path)) {
    stop(
      "could not move the downloaded model into the appc data directory",
      call. = FALSE
    )
  }

  invisible(path)
}

load_rf_pm_model <- function(model_version = "2") {
  st <- Sys.time()
  model_cache_key <- paste0("model_v", model_version)
  if (!exists(model_cache_key, envir = .appc_cache, inherits = FALSE)) {
    grf_file <- fs::path(
      tools::R_user_dir("appc", "data"),
      glue::glue("rf_pm_v{model_version}.rds")
    )
    checksums <- .rf_pm_model_checksums[[model_version]]
    if (
      file.exists(grf_file) &&
        !rf_pm_model_checksum_matches(grf_file, checksums)
    ) {
      warning(
        "cached rf_pm_v",
        model_version,
        " model failed checksum verification; downloading a fresh copy",
        call. = FALSE
      )
      unlink(grf_file)
    }
    if (!file.exists(grf_file)) {
      download_rf_pm_model(grf_file, model_version, checksums)
    }
    assign(
      model_cache_key,
      readRDS(grf_file),
      envir = .appc_cache
    )
  }
  model <- get(model_cache_key, envir = .appc_cache, inherits = FALSE)
  et <- Sys.time()
  message(
    "loaded rf_pm_v",
    model_version,
    " in ",
    as.integer(difftime(et, st, units = "secs")),
    "s"
  )
  return(model)
}

#' Get daily PM2.5 model predictions
#'
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a list of date vectors for the predictions, must be the same length as `x`
#' @param keep_predictors logical; return values for model predictors alongside PM2.5 estimates?
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
#' \dontrun{
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
#' }
predict_pm25 <- function(x, dates, keep_predictors = FALSE) {
  check_s2_dates(x, dates)
  cli::cli_progress_step("(down)loading random forest model")
  grf <- load_rf_pm_model()
  cli::cli_progress_done()
  required_predictors <- names(grf$X.orig)
  d <- assemble_predictors(x = x, dates = dates, pollutant = "pm25")
  stopifnot(all(required_predictors %in% names(d)))
  stopifnot(inherits(grf, "regression_forest"))
  loadNamespace("grf")
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

  if (keep_predictors) {
    d_pred <- dplyr::bind_cols(
      d_pred,
      dplyr::select(d, dplyr::all_of(required_predictors))
    )
  }

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
#' \dontrun{
#' predict_pm25_date_range(
#'   x = c("8841b39a7c46e25f", "8841a45555555555"),
#'   start_date = as.Date(c("2023-05-18", "2023-01-06")),
#'   end_date = as.Date(c("2023-06-22", "2023-08-15")),
#'   average = TRUE
#' )
#' }
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
