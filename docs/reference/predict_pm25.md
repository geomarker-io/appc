# Get daily PM2.5 model predictions

Get daily PM2.5 model predictions

## Usage

``` r
predict_pm25(x, dates, keep_predictors = FALSE)
```

## Arguments

- x:

  a vector of s2 cell identifers (`s2_cell` object)

- dates:

  a list of date vectors for the predictions, must be the same length as
  `x`

- keep_predictors:

  logical; return values for model predictors alongside PM2.5 estimates?

## Value

a list of tibbles the same length as `x`, each containing columns for
the predicted (`pm25`) and its standard error (`pm25_se`); with one row
per date in `dates`. These numerics are the concentrations of fine
particulate matter, measured in micrograms per cubic meter. See
`vignette("cv-model-performance")` for more details on the cross
validated accuracy of the daily PM2.5 model predictions.

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
} # }
```
