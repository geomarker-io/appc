# Get daily PM2.5 model predictions

Get daily PM2.5 model predictions

## Usage

``` r
predict_pm25(x, dates, keep_predictors = FALSE)

# S3 method for class 's2cd'
predict_pm25(x, dates = NULL, keep_predictors = FALSE)

# Default S3 method
predict_pm25(x, dates, keep_predictors = FALSE)

# S3 method for class 's2_cell'
predict_pm25(x, dates, keep_predictors = FALSE)
```

## Arguments

- x:

  a vector of s2 cell identifiers (`s2_cell` object), or a
  [`geomarker::s2cd()`](https://geomarker.io/geomarker/reference/s2cd.html)
  object containing both locations and prediction dates

- dates:

  a list of date vectors for the predictions, the same length as `x`;
  omit for `s2cd` objects because their stored dates are used

- keep_predictors:

  logical; return values for model predictors alongside PM2.5 estimates?

## Value

a list of tibbles the same length as `x`, each containing columns for
the predicted (`pm25`) and its standard error (`pm25_se`); with one row
per requested date. These numerics are the concentrations of fine
particulate matter, measured in micrograms per cubic meter. See the
[model-performance
report](https://geomarker.io/appc/articles/cv-model-performance.html)
for more details on the cross validated accuracy of the daily PM2.5
model predictions.

## Details

Internally, loading the model file is cached, so repeated calls in the
same R session will not require the overhead of loading the model file
for a new prediction.

## Examples

``` r
if (FALSE) { # \dontrun{
d <- list(
  "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
  "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
)

predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)

# takes less time after called once because model file is cached in memory

d <- list(
  "8841b39a7c46e25f" = as.Date(c("2023-05-13", "2023-11-16")),
  "8841a45555555555" = as.Date(c("2023-06-21", "2023-08-25"))
)
predict_pm25(x = s2::as_s2_cell(names(d)), dates = d)

# locations and dates can also be supplied together
locations <- geomarker::s2cd(s2::as_s2_cell(names(d)), dates = d)
predict_pm25(locations, keep_predictors = TRUE)
} # }
```
