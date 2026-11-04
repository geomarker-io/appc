# Timeline Example

``` r

library(appc)
library(dplyr, warn.conflicts = FALSE)
```

This example details how to use the appc package to add air pollution
exposure estimates for exact locations and time periods defined by
geocoded coordinates and a “key” date. For this example workflow, we
will simulate 20 random locations in Wayne County, Michigan and dates of
birth during 2023, but in actuality this can be any set of geocoded
`lat` and `lon` columns with corresponding dates.

``` r

d <-
  tigris::counties("MI", year = 2021, progress_bar = FALSE) |>
  suppressWarnings() |>
  filter(GEOID == 26163) |>
  sf::st_sample(20) |>
  sf::st_coordinates() |>
  tibble::as_tibble() |>
  rename(lat = Y, lon = X) |>
  mutate(dob = sample(seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = 1), size = 20))

d
#> # A tibble: 20 × 3
#>      lon   lat dob
#>    <dbl> <dbl> <date>
#>  1 -83.5  42.3 2023-10-31
#>  2 -82.9  42.4 2023-11-27
#>  3 -83.4  42.1 2023-10-18
#>  4 -83.2  42.2 2023-05-10
#>  5 -83.2  42.3 2023-12-09
#>  6 -83.3  42.3 2023-05-11
#>  7 -82.9  42.4 2023-10-21
#>  8 -83.3  42.2 2023-08-22
#>  9 -83.2  42.2 2023-03-06
#> 10 -83.4  42.2 2023-08-19
#> 11 -83.2  42.1 2023-05-30
#> 12 -83.5  42.3 2023-05-27
#> 13 -83.2  42.2 2023-09-15
#> 14 -83.3  42.1 2023-11-16
#> 15 -83.4  42.2 2023-02-09
#> 16 -83.5  42.3 2023-07-12
#> 17 -83.5  42.4 2023-06-05
#> 18 -83.4  42.3 2023-01-12
#> 19 -83.3  42.3 2023-10-24
#> 20 -83.2  42.2 2023-02-11
```

For this example, we want to estimate fine particulate matter from birth
through 90 days after birth. Using the dob column as the start date, we
will define an end date in our example data and also define the s2 cell
identifers based on the latitude and longitude coordinates.

``` r

d <- d |>
  mutate(
    dob_plus_90 = dob + 90,
    s2 = s2::as_s2_cell(s2::s2_geog_point(lon, lat))
  )

head(d)
#> # A tibble: 6 × 5
#>     lon   lat dob        dob_plus_90 s2
#>   <dbl> <dbl> <date>     <date>      <s2cell>
#> 1 -83.5  42.3 2023-10-31 2024-01-29  883b539fde6f468f
#> 2 -82.9  42.4 2023-11-27 2024-02-25  882529be4afb184b
#> 3 -83.4  42.1 2023-10-18 2024-01-16  883b5cadcae041d3
#> 4 -83.2  42.2 2023-05-10 2023-08-08  883b36dae69ea671
#> 5 -83.2  42.3 2023-12-09 2024-03-08  883b339ae99f458f
#> 6 -83.3  42.3 2023-05-11 2023-08-09  883b4b9750a4f19d
```

Next, use the newly created columns to call the
[`predict_pm25_date_range()`](https://geomarker.io/appc/reference/predict_pm25_date_range.md)
function, which is a simpler implementation of predict_pm25 that takes
vectors of start and end dates instead of lists of date vectors for each
s2 cell location:

``` r

dplyr::mutate(d, pm25 = predict_pm25_date_range(s2, dob, dob_plus_90))
#> Warning: There were 2 warnings in `dplyr::mutate()`.
#> The first warning was:
#> ℹ In argument: `pm25 = predict_pm25_date_range(s2, dob, dob_plus_90)`.
#> Caused by warning in `st_is_longlat()`:
#> ! bounding box has potentially an invalid value range for longlat data
#> ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.
#> # A tibble: 20 × 6
#>      lon   lat dob        dob_plus_90 s2               pm25
#>    <dbl> <dbl> <date>     <date>      <s2cell>         <list>
#>  1 -83.5  42.3 2023-10-31 2024-01-29  883b539fde6f468f <tibble [91 × 2]>
#>  2 -82.9  42.4 2023-11-27 2024-02-25  882529be4afb184b <tibble [91 × 2]>
#>  3 -83.4  42.1 2023-10-18 2024-01-16  883b5cadcae041d3 <tibble [91 × 2]>
#>  4 -83.2  42.2 2023-05-10 2023-08-08  883b36dae69ea671 <tibble [91 × 2]>
#>  5 -83.2  42.3 2023-12-09 2024-03-08  883b339ae99f458f <tibble [91 × 2]>
#>  6 -83.3  42.3 2023-05-11 2023-08-09  883b4b9750a4f19d <tibble [91 × 2]>
#>  7 -82.9  42.4 2023-10-21 2024-01-19  8824d53e3f2addd3 <tibble [91 × 2]>
#>  8 -83.3  42.2 2023-08-22 2023-11-20  883b462c96efefa9 <tibble [91 × 2]>
#>  9 -83.2  42.2 2023-03-06 2023-06-04  883b37c7f61125bf <tibble [91 × 2]>
#> 10 -83.4  42.2 2023-08-19 2023-11-17  883b44e161d94b5d <tibble [91 × 2]>
#> 11 -83.2  42.1 2023-05-30 2023-08-28  883b3f38bc72bc79 <tibble [91 × 2]>
#> 12 -83.5  42.3 2023-05-27 2023-08-25  883b5129692a69f7 <tibble [91 × 2]>
#> 13 -83.2  42.2 2023-09-15 2023-12-14  883b362d7f446e2d <tibble [91 × 2]>
#> 14 -83.3  42.1 2023-11-16 2024-02-14  883b41493a95f44f <tibble [91 × 2]>
#> 15 -83.4  42.2 2023-02-09 2023-05-10  883b451132452249 <tibble [91 × 2]>
#> 16 -83.5  42.3 2023-07-12 2023-10-10  883b56ca718e3a5b <tibble [91 × 2]>
#> 17 -83.5  42.4 2023-06-05 2023-09-03  8824abeaf2f4640b <tibble [91 × 2]>
#> 18 -83.4  42.3 2023-01-12 2023-04-12  883b4ef3cd3ded53 <tibble [91 × 2]>
#> 19 -83.3  42.3 2023-10-24 2024-01-22  883b496b4a4bf401 <tibble [91 × 2]>
#> 20 -83.2  42.2 2023-02-11 2023-05-12  883b3733a728db21 <tibble [91 × 2]>
```

If interested in average exposures (and their uncertainties) from start
date to end date (instead of daily exposures), we can extract those
directly:

``` r

d_pm25 <- with(d, predict_pm25_date_range(s2, dob, dob_plus_90, average = TRUE))
#> Warning in st_is_longlat(x): bounding box has potentially an invalid value
#> range for longlat data
#> Warning in st_is_longlat(x): bounding box has potentially an invalid value
#> range for longlat data
bind_cols(d, bind_rows(d_pm25))
#> # A tibble: 20 × 7
#>      lon   lat dob        dob_plus_90 s2                pm25 pm25_se
#>    <dbl> <dbl> <date>     <date>      <s2cell>         <dbl>   <dbl>
#>  1 -83.5  42.3 2023-10-31 2024-01-29  883b539fde6f468f  9.19   0.153
#>  2 -82.9  42.4 2023-11-27 2024-02-25  882529be4afb184b  9.32   0.165
#>  3 -83.4  42.1 2023-10-18 2024-01-16  883b5cadcae041d3  8.31   0.155
#>  4 -83.2  42.2 2023-05-10 2023-08-08  883b36dae69ea671 15.2    0.516
#>  5 -83.2  42.3 2023-12-09 2024-03-08  883b339ae99f458f  9.42   0.156
#>  6 -83.3  42.3 2023-05-11 2023-08-09  883b4b9750a4f19d 14.6    0.337
#>  7 -82.9  42.4 2023-10-21 2024-01-19  8824d53e3f2addd3  8.57   0.163
#>  8 -83.3  42.2 2023-08-22 2023-11-20  883b462c96efefa9  7.09   0.113
#>  9 -83.2  42.2 2023-03-06 2023-06-04  883b37c7f61125bf  8.22   0.136
#> 10 -83.4  42.2 2023-08-19 2023-11-17  883b44e161d94b5d  7.20   0.116
#> 11 -83.2  42.1 2023-05-30 2023-08-28  883b3f38bc72bc79 15.0    0.501
#> 12 -83.5  42.3 2023-05-27 2023-08-25  883b5129692a69f7 14.6    0.336
#> 13 -83.2  42.2 2023-09-15 2023-12-14  883b362d7f446e2d  7.22   0.133
#> 14 -83.3  42.1 2023-11-16 2024-02-14  883b41493a95f44f  9.23   0.153
#> 15 -83.4  42.2 2023-02-09 2023-05-10  883b451132452249  7.31   0.119
#> 16 -83.5  42.3 2023-07-12 2023-10-10  883b56ca718e3a5b  9.75   0.176
#> 17 -83.5  42.4 2023-06-05 2023-09-03  8824abeaf2f4640b 14.1    0.365
#> 18 -83.4  42.3 2023-01-12 2023-04-12  883b4ef3cd3ded53  7.73   0.135
#> 19 -83.3  42.3 2023-10-24 2024-01-22  883b496b4a4bf401  8.70   0.149
#> 20 -83.2  42.2 2023-02-11 2023-05-12  883b3733a728db21  7.71   0.141
```
