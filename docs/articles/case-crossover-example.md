# Case-Crossover Example

``` r

library(appc)
library(dplyr, warn.conflicts = FALSE)
```

This example details how to use the appc package to add air pollution
exposure estimates for exact locations and dates defined by geocoded
coordinates and a case date. For this example workflow, we will simulate
20 random locations in Wayne County, Michigan and case dates in 2022,
but in actuality this can be any set of geocoded `lat` and `lon` columns
with corresponding dates.

``` r

d <-
  tigris::counties("MI", year = 2021, progress_bar = FALSE) |>
  suppressWarnings() |>
  filter(GEOID == 26163) |>
  sf::st_sample(20) |>
  sf::st_coordinates() |>
  tibble::as_tibble() |>
  rename(lat = Y, lon = X) |>
  mutate(case_date = sample(seq(as.Date("2022-01-01"), as.Date("2022-12-31"), by = 1), size = 20)) |>
  mutate(id = 1:20) |>
  relocate(id)

d
#> # A tibble: 20 × 4
#>       id   lon   lat case_date
#>    <int> <dbl> <dbl> <date>
#>  1     1 -83.5  42.3 2022-10-31
#>  2     2 -82.9  42.4 2022-11-27
#>  3     3 -83.4  42.1 2022-10-18
#>  4     4 -83.2  42.2 2022-05-10
#>  5     5 -83.2  42.3 2022-12-09
#>  6     6 -83.3  42.3 2022-05-11
#>  7     7 -82.9  42.4 2022-10-21
#>  8     8 -83.3  42.2 2022-08-22
#>  9     9 -83.2  42.2 2022-03-06
#> 10    10 -83.4  42.2 2022-08-19
#> 11    11 -83.2  42.1 2022-05-30
#> 12    12 -83.5  42.3 2022-05-27
#> 13    13 -83.2  42.2 2022-09-15
#> 14    14 -83.3  42.1 2022-11-16
#> 15    15 -83.4  42.2 2022-02-09
#> 16    16 -83.5  42.3 2022-07-12
#> 17    17 -83.5  42.4 2022-06-05
#> 18    18 -83.4  42.3 2022-01-12
#> 19    19 -83.3  42.3 2022-10-24
#> 20    20 -83.2  42.2 2022-02-11
```

For each case, we estimate fine particulate matter on the case date and
on control dates in the same year and month that fall on the same day of
the week. The date list for each location includes the case date and its
controls.

``` r

dates_seq <- seq(min(d$case_date) - 31, max(d$case_date) + 31, by = 1)

make_control_dates <- function(case_date) {
  dates_seq[lubridate::year(dates_seq) == lubridate::year(case_date) &
              lubridate::month(dates_seq) == lubridate::month(case_date) &
              lubridate::wday(dates_seq) == lubridate::wday(case_date) &
              dates_seq != case_date]
}

d <- d |>
  mutate(dates = purrr::map(case_date, \(date) sort(c(date, make_control_dates(date)))))

d
#> # A tibble: 20 × 5
#>       id   lon   lat case_date  dates
#>    <int> <dbl> <dbl> <date>     <list>
#>  1     1 -83.5  42.3 2022-10-31 <date [5]>
#>  2     2 -82.9  42.4 2022-11-27 <date [4]>
#>  3     3 -83.4  42.1 2022-10-18 <date [4]>
#>  4     4 -83.2  42.2 2022-05-10 <date [5]>
#>  5     5 -83.2  42.3 2022-12-09 <date [5]>
#>  6     6 -83.3  42.3 2022-05-11 <date [4]>
#>  7     7 -82.9  42.4 2022-10-21 <date [4]>
#>  8     8 -83.3  42.2 2022-08-22 <date [5]>
#>  9     9 -83.2  42.2 2022-03-06 <date [4]>
#> 10    10 -83.4  42.2 2022-08-19 <date [4]>
#> 11    11 -83.2  42.1 2022-05-30 <date [5]>
#> 12    12 -83.5  42.3 2022-05-27 <date [4]>
#> 13    13 -83.2  42.2 2022-09-15 <date [5]>
#> 14    14 -83.3  42.1 2022-11-16 <date [5]>
#> 15    15 -83.4  42.2 2022-02-09 <date [4]>
#> 16    16 -83.5  42.3 2022-07-12 <date [4]>
#> 17    17 -83.5  42.4 2022-06-05 <date [4]>
#> 18    18 -83.4  42.3 2022-01-12 <date [4]>
#> 19    19 -83.3  42.3 2022-10-24 <date [5]>
#> 20    20 -83.2  42.2 2022-02-11 <date [4]>
```

Next, we will use the `lon` and `lat` columns to create the s2 geohash:

``` r

d <- d |> dplyr::mutate(s2 = s2::as_s2_cell(s2::s2_geog_point(lon, lat)))

d
#> # A tibble: 20 × 6
#>       id   lon   lat case_date  dates      s2
#>    <int> <dbl> <dbl> <date>     <list>     <s2cell>
#>  1     1 -83.5  42.3 2022-10-31 <date [5]> 883b539fde6f468f
#>  2     2 -82.9  42.4 2022-11-27 <date [4]> 882529be4afb184b
#>  3     3 -83.4  42.1 2022-10-18 <date [4]> 883b5cadcae041d3
#>  4     4 -83.2  42.2 2022-05-10 <date [5]> 883b36dae69ea671
#>  5     5 -83.2  42.3 2022-12-09 <date [5]> 883b339ae99f458f
#>  6     6 -83.3  42.3 2022-05-11 <date [4]> 883b4b9750a4f19d
#>  7     7 -82.9  42.4 2022-10-21 <date [4]> 8824d53e3f2addd3
#>  8     8 -83.3  42.2 2022-08-22 <date [5]> 883b462c96efefa9
#>  9     9 -83.2  42.2 2022-03-06 <date [4]> 883b37c7f61125bf
#> 10    10 -83.4  42.2 2022-08-19 <date [4]> 883b44e161d94b5d
#> 11    11 -83.2  42.1 2022-05-30 <date [5]> 883b3f38bc72bc79
#> 12    12 -83.5  42.3 2022-05-27 <date [4]> 883b5129692a69f7
#> 13    13 -83.2  42.2 2022-09-15 <date [5]> 883b362d7f446e2d
#> 14    14 -83.3  42.1 2022-11-16 <date [5]> 883b41493a95f44f
#> 15    15 -83.4  42.2 2022-02-09 <date [4]> 883b451132452249
#> 16    16 -83.5  42.3 2022-07-12 <date [4]> 883b56ca718e3a5b
#> 17    17 -83.5  42.4 2022-06-05 <date [4]> 8824abeaf2f4640b
#> 18    18 -83.4  42.3 2022-01-12 <date [4]> 883b4ef3cd3ded53
#> 19    19 -83.3  42.3 2022-10-24 <date [5]> 883b496b4a4bf401
#> 20    20 -83.2  42.2 2022-02-11 <date [4]> 883b3733a728db21
```

Then we can directly use the `s2` and `dates` columns to add temperature
and humidity using the `get_narr_data()` function and PM2.5 using the
[`predict_pm25()`](https://geomarker.io/appc/reference/predict_pm25.md)
function:

``` r

d <- d |> dplyr::mutate(temperature = geomarker::get_narr_data(geomarker::s2cd(s2, dates), "air.2m"),
                        humidity = geomarker::get_narr_data(geomarker::s2cd(s2, dates), "rhum.2m"))

d <- d |> dplyr::mutate(pm25 = predict_pm25(s2, dates))

d |>
  select(id, case_date, dates, pm25) |>
  tidyr::unnest(c(dates, pm25)) |>
  mutate(is_case_date = dates == case_date) |>
  head()
#> # A tibble: 6 × 6
#>      id case_date  dates       pm25 pm25_se is_case_date
#>   <int> <date>     <date>     <dbl>   <dbl> <lgl>
#> 1     1 2022-10-31 2022-10-03  6.09   1.29  FALSE
#> 2     1 2022-10-31 2022-10-10  7.52   0.847 FALSE
#> 3     1 2022-10-31 2022-10-17  2.83   0.333 FALSE
#> 4     1 2022-10-31 2022-10-24 11.3    0.781 FALSE
#> 5     1 2022-10-31 2022-10-31 11.0    1.62  TRUE
#> 6     2 2022-11-27 2022-11-06  5.14   0.962 FALSE
```
