test_that("model generation and dependency are pinned independently of appc version", {
  spec <- model_spec()
  expect_identical(spec$model_version, "3")
  expect_identical(spec$geomarker_version, "0.2.0")
  expect_identical(
    spec$geomarker_sha,
    "373820d0ab8082f856f7bf0f639f3128111d825a"
  )
  expect_identical(spec$coverage_end, as.Date("2026-06-30"))
  expect_length(spec$predictors, 20)
  expect_match(model_artifact_path("training"), "training_data_v3[.]rds$")
  expect_match(model_artifact_path(), "rf_pm_v3[.]rds$")
  metadata <- training_metadata()
  expect_identical(metadata$geomarker$sha, spec$geomarker_sha)
  expect_named(metadata$geomarker_data_manifests, c("elevation", "merra"))
})

test_that("artifact provenance must match the feature and dependency specification", {
  object <- structure(list(), appc_model_training = training_metadata())
  expect_silent(validate_training_metadata(object))
  attr(object, "appc_model_training")$spec$model_version <- "2"
  expect_error(validate_training_metadata(object), "metadata")
  attr(object, "appc_model_training") <- training_metadata()
  attr(object, "appc_model_training")$geomarker$sha <- "other-source"
  expect_error(validate_training_metadata(object), "metadata")
  expect_error(validate_training_metadata(list()), "metadata")
})

test_that("artifact writes require a new path", {
  path <- tempfile()
  expect_silent(check_new_artifact(path))
  saveRDS("existing", path)
  expect_error(check_new_artifact(path), "Refusing to overwrite")
  expect_identical(readRDS(path), "existing")
})

test_that("the public API retains models and outcomes without environmental wrappers", {
  exports <- getNamespaceExports("appc")
  expect_setequal(
    exports,
    c(
      "appc_clean_data_directory",
      "assemble_predictors",
      "get_daily_aqs",
      "install_aqs",
      "latlon_to_s2_cell",
      "predict_pm25",
      "predict_pm25_date_range"
    )
  )
})
