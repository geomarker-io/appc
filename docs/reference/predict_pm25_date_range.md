# Get daily PM2.5 model predictions using date ranges

Get daily PM2.5 model predictions using date ranges

## Usage

``` r
predict_pm25_date_range(x, start_date, end_date, average = FALSE)
```

## Arguments

- x:

  a vector of s2 cell identifers (`s2_cell` object)

- start_date:

  a date vector of start dates for each s2 cell, must be the same length
  as `x`

- end_date:

  a date vector of end dates for each s2 cell, must be the same length
  as `x`

- average:

  logical; summarize daily exposures estimates and standard errors?

## Details

The standard error for averages of daily pm25 exposures with known
standard errors is calculated, assuming they are independent, as the
square root of the sum of squared individual standard errors divided the
total number of individual daily pm25 exposures.

## Examples

``` r
if (FALSE) { # \dontrun{
predict_pm25_date_range(
  x = c("8841b39a7c46e25f", "8841a45555555555"),
  start_date = as.Date(c("2023-05-18", "2023-01-06")),
  end_date = as.Date(c("2023-06-22", "2023-08-15")),
  average = TRUE
)
} # }
```
