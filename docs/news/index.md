# Changelog

## appc 2.99.0.9000

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
