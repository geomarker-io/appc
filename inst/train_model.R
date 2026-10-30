library(dplyr, warn.conflicts = FALSE)
library(purrr)
library(grf)

# load development version if developing (instead of currently installed version)
if (file.exists("./inst")) {
  devtools::load_all()
} else {
  library(appc)
}

spec <- appc:::model_spec()
# Check the pinned training environment before reading data or fitting.
invisible(appc:::training_metadata())
train_file_output_path <- appc:::model_artifact_path("training")
file_output_path <- appc:::model_artifact_path("model")
appc:::check_new_artifact(file_output_path)
if (!file.exists(train_file_output_path)) {
  stop(
    "No v3 training data are available. Run just make_training_data first.",
    call. = FALSE
  )
}
d_train <- readRDS(train_file_output_path)
metadata <- appc:::validate_training_metadata(d_train)
pred_names <- spec$predictors
stopifnot(
  "training data do not contain the required predictors" = all(
    pred_names %in% names(d_train)
  ),
  "training concentrations contain missing values" = !anyNA(d_train$conc)
)

cli::cli_progress_step("training GRF")
num_threads <- parallel::detectCores()
if (is.na(num_threads) || num_threads < 1L) {
  num_threads <- 1L
}
grf <-
  regression_forest(
    X = select(d_train, all_of(pred_names)),
    Y = d_train$conc,
    seed = 224,
    num.threads = num_threads,
    num.trees = 200,
    compute.oob.predictions = TRUE,
    honesty = FALSE,
    tune.parameters = "none",
    sample.fraction = 0.5,
    min.node.size = 5,
    alpha = 0.05,
    imbalance.penalty = 0,
    clusters = as.factor(d_train$s2),
    equalize.cluster.weights = FALSE
  )

cli::cli_progress_step("saving GRF")
attr(grf, "appc_model_training") <- metadata
saveRDS(grf, file_output_path, compress = "gzip", version = 3)
cli::cli_alert_info(
  "saved rf_pm rds file ({fs::file_info(file_output_path)$size}) to {file_output_path}"
)
cli::cli_progress_done()
