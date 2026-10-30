# Assemble predictors for the PM2.5 model

Uses geomarker for environmental assessment and adds model-specific
spatial and calendar terms. The same implementation is used for training
and prediction.

## Usage

``` r
assemble_predictors(x, dates, pollutant = c("pm25"))
```

## Arguments

- x:

  a vector of level-30 `s2_cell` locations within the contiguous US

- dates:

  a list of nonempty Date vectors, the same length as `x`

- pollutant:

  reserved for future pollutant-specific predictors

## Value

A tibble with one row per requested location-date, in input order.
Duplicate locations and dates are preserved.

## Examples

``` r
if (FALSE) { # \dontrun{
assemble_predictors(
  s2::as_s2_cell("8841b39a7c46e25f"),
  list(as.Date(c("2023-05-18", "2023-11-06")))
)
} # }
```
