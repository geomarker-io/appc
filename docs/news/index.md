# Changelog

## appc 2.99.0.9000

- Require terra 1.9.46 or newer for the compressed NetCDF extraction
  fix, and allow completed AQS refreshes to be reused with
  `options(appc.refresh_aqs = FALSE)`.
- Retry transient EPA API failures and resume incomplete AQS refreshes
  from harmonized state checkpoints without replacing the last complete
  annual extract.
- Include Idaho and North Dakota in AQS API refreshes for complete
  contiguous-US coverage.
- [`predict_pm25()`](https://geomarker.io/appc/reference/predict_pm25.md)
  now accepts geomarker `s2cd` objects directly, using their stored
  dates and retaining the existing list-of-tibbles output.
- Prepare model generation 3 for January 2017 through June 2026 using
  geomarker 0.2.0, pinned to release commit
  373820d0ab8082f856f7bf0f639f3128111d825a.
- Share geomarker-backed predictor assembly between the committed
  training-data script and prediction, preserving input location/date
  order and duplicates.
- Keep AQS outcome harmonization and the existing GRF training
  specification.
- Remove standalone environmental assessment and installation APIs; use
  geomarker for those functions. Elevation now comes from USGS 3DEP
  rather than the v2 PRISM source, so the v2 model cannot be reused with
  these inputs.
- Record model generation separately from package version, preserve
  training provenance, and require matching metadata for local v3 model
  artifacts.
- Full v3 training and publication are still required. Documentation
  does not present v2 predictions or performance as results from v3.

## appc 2.0.1

- Load the PM2.5 model from a portable RDS artifact
  ([\#119](https://github.com/geomarker-io/appc/pull/119)).

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v2.0.1)

## appc 2.0.0

- Release a new PM2.5 model and training data covering January 2017
  through June 2026
  ([\#118](https://github.com/geomarker-io/appc/pull/118)).

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v2.0.0)

## appc 1.0.2

- Switch model serialization from qs to qs2
  ([\#117](https://github.com/geomarker-io/appc/pull/117)).

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v1.0.2)

## appc 1.0.1

- Add `keep_predictors` to
  [`predict_pm25()`](https://geomarker.io/appc/reference/predict_pm25.md)
  to optionally return predictors alongside predictions.
- Validate buffer arguments and improve the README and vignettes.
- Retain the existing model, data, and prediction values.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v1.0.1)

## appc 1.0.0

- Retrain the random forest with updated observations, replacing
  predictions across the entire January 2017 through October 2025
  coverage period.
- Update Annual NLCD to include 2024 data, and update HMS smoke, NARR,
  and gridMET availability for 2025.
- Add traffic summaries by vehicle class and NEI point-source
  assessments.
- Add AQS Data Mart installation for more recent daily PM2.5
  observations.
- Add `force_reinstall` for refreshing installed source data.
- Fix maximum-date validation, update gridMET download URLs, and use
  `EARTHDATA_USER` for NASA authentication.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v1.0.0)

## appc 0.6.1

- Fix downloading the latest model when rendering the model-performance
  vignette.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v0.6.1)

## appc 0.6.0

- Add
  [`predict_pm25_date_range()`](https://geomarker.io/appc/reference/predict_pm25_date_range.md)
  and
  [`latlon_to_s2_cell()`](https://geomarker.io/appc/reference/latlon_to_s2_cell.md).
- Cache the loaded model in memory for repeated predictions within an R
  session.
- Associate model and training artifacts with the package major version,
  allowing minor and patch releases to reuse the same model.
- Add configurable minimum and maximum dates to internal input
  validation.
- Update the NLCD fractional-imperviousness download URL.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v0.6.0)

## appc 0.5.1

- Fix the NLCD fractional-imperviousness download URL
  ([\#90](https://github.com/geomarker-io/appc/pull/90)).

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v0.5.1)

## appc 0.5.0

- Extend supported prediction dates through the end of 2024; bulk AQS
  training observations were available through October 2024 at release
  time.
- Add the newer Annual NLCD product as an assessment function, without
  including it in the model.
- Distribute MERRA-2 data under dedicated data-release tags rather than
  package version tags.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v0.5.0)

## appc 0.4.0

- Incorporate available 2024 observations and update the trained model.
- Fix MERRA source installation using response URLs.
- Install smoke data from its original source on first use instead of
  distributing it as a package release asset.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v0.4.0)

## appc 0.3.0

- Add gridMET assessment functions and retrain the model using gridMET
  weather predictors in place of NARR variables, retaining NARR `hpbl`.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v0.3.0)

## appc 0.2.0

- Publish the first stable release with a finalized PM2.5 prediction
  model.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v0.2.0)

## appc 0.1.0

- Publish the initial release for model development.

[Release
notes](https://github.com/geomarker-io/appc/releases/tag/v0.1.0)
