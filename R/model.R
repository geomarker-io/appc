# Model generation is independent of the pre-release package version.
model_spec <- function() {
  d <- read.dcf(system.file(
    "model-v3-spec.dcf",
    package = "appc",
    mustWork = TRUE
  ))
  words <- function(field) strsplit(d[1, field], "[[:space:]]+")[[1]]
  list(
    model_version = unname(d[1, "Model-Version"]),
    coverage_start = as.Date(unname(d[1, "Coverage-Start"])),
    coverage_end = as.Date(unname(d[1, "Coverage-End"])),
    geomarker_version = unname(d[1, "Geomarker-Version"]),
    geomarker_tag = unname(d[1, "Geomarker-Tag"]),
    geomarker_sha = unname(d[1, "Geomarker-SHA"]),
    coordinate_crs = as.integer(d[1, "Coordinate-CRS"]),
    elevation_buffer = as.numeric(d[1, "Elevation-Buffer-Meters"]),
    smoke_summary = unname(d[1, "Smoke-Summary"]),
    gridmet = stats::setNames(
      words("GridMET-Variables"),
      words("GridMET-Predictors")
    ),
    narr_variable = unname(d[1, "NARR-Variable"]),
    merra_columns = words("MERRA-Columns"),
    predictors = words("Predictors")
  )
}

training_metadata <- function() {
  spec <- model_spec()
  description <- utils::packageDescription("geomarker")
  sha <- description$RemoteSha
  if (is.null(sha)) {
    sha <- description$GithubSHA1
  }
  if (
    !identical(description$Version, spec$geomarker_version) ||
      !identical(sha, spec$geomarker_sha)
  ) {
    stop(
      "Training requires geomarker ",
      spec$geomarker_version,
      " from commit ",
      spec$geomarker_sha,
      ". Install the pinned dependency with pak::pak() ",
      "from the appc repository. A version number alone is not sufficient.",
      call. = FALSE
    )
  }
  manifests <- lapply(
    c("elevation-data.dcf", "merra-data.dcf"),
    function(file) {
      read.dcf(system.file(file, package = "geomarker", mustWork = TRUE))
    }
  )
  names(manifests) <- c("elevation", "merra")
  list(
    spec = spec,
    appc_version = as.character(utils::packageVersion("appc")),
    geomarker = list(version = description$Version, sha = sha),
    geomarker_data_manifests = manifests,
    built_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    session = utils::sessionInfo()
  )
}

validate_training_metadata <- function(object) {
  metadata <- attr(object, "appc_model_training")
  spec <- model_spec()
  if (
    !identical(metadata$spec, spec) ||
      !identical(metadata$geomarker$version, spec$geomarker_version) ||
      !identical(metadata$geomarker$sha, spec$geomarker_sha)
  ) {
    stop(
      "Artifact metadata do not match the v3 model specification.",
      call. = FALSE
    )
  }
  invisible(metadata)
}

attach_training_outcome <- function(predictors, cells, dates, concentrations) {
  expected_cells <- rep(as.character(cells), lengths(dates))
  expected_dates <- do.call(c, dates)
  outcome <- unlist(concentrations, use.names = FALSE)
  if (
    !identical(as.character(predictors$s2), expected_cells) ||
      !identical(as.numeric(predictors$date), as.numeric(expected_dates)) ||
      nrow(predictors) != length(outcome) ||
      !identical(lengths(dates), lengths(concentrations))
  ) {
    stop(
      "Predictor S2/date rows do not align with AQS concentrations.",
      call. = FALSE
    )
  }
  predictors$conc <- outcome
  predictors
}

model_artifact_path <- function(kind = c("model", "training")) {
  kind <- match.arg(kind)
  prefix <- if (kind == "model") "rf_pm_v" else "training_data_v"
  file.path(
    tools::R_user_dir("appc", "data"),
    paste0(prefix, model_spec()$model_version, ".rds")
  )
}

check_new_artifact <- function(path) {
  if (file.exists(path)) {
    stop(
      "Refusing to overwrite existing artifact: ",
      path,
      ". Move it aside before rebuilding.",
      call. = FALSE
    )
  }
  invisible(path)
}
