
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Air Pollution Prediction Commons

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml)
[![CRAN
status](https://www.r-pkg.org/badges/version/appc)](https://CRAN.R-project.org/package=appc)
<!-- badges: end -->

## About

The goal of the appc package is to provide daily, high resolution, near
real-time, model-based ambient air pollution exposure assessments. This
is achieved by training a generalized random forest on several
geomarkers to predict daily average EPA AQS concentrations from 2017
until the present at exact locations across the contiguous United
States. The appc package contains functions for generating geomarker
predictors and the ambient air pollution concentrations. Predictor
geomarkers include weather and atmospheric information, traffic on
primary roadways, urban imperviousness, wildfire smoke, industrial
emissions, elevation, spatiotemporal indicators, and satellite-based
aerosol diagnostics data. Source files included with the package train
and evaluate models that can be updated with any release to use more
recent AQS measurements and/or geomarker predictors.

## Example

In R, create model-based predictions of ambient air pollution
concentrations at exact locations on specific dates:

``` r
appc::predict_pm25(
  x = s2::as_s2_cell(c("8841b39a7c46e25f", "8841a45555555555")),
  dates = list(as.Date(c("2023-05-18", "2023-11-06")), as.Date(c("2023-06-22", "2023-08-15")))
)
#> $`8841b39a7c46e25f`
#> # A tibble: 2 × 2
#>    pm25 pm25_se
#>   <dbl>   <dbl>
#> 1  8.36    1.21
#> 2 10.9     2.21
#> 
#> $`8841a45555555555`
#> # A tibble: 2 × 2
#>    pm25 pm25_se
#>   <dbl>   <dbl>
#> 1  5.39   0.496
#> 2  7.99   3.21
```

Installed geomarker data sources and the grf model are hosted as release
assets on GitHub and are downloaded locally to the package-specific R
user data directory (i.e., `tools::R_user_dir("appc", "data")`). These
files are cached across all of an R user’s sessions and projects.
(Specify an alternative download location by setting the
`R_USER_DATA_DIR` environment variable; see `?tools::R_user_dir`.)

## S2 geohash

The [s2 geohash](https://s2geometry.io/) is a
[hierarchical](https://s2geometry.io/devguide/s2cell_hierarchy.html)
geospatial index that uses [spherical
geometry](https://s2geometry.io/about/overview). The appc package uses
s2 cells via the [s2](https://r-spatial.github.io/s2/) package to
specify geospatial locations. In R, s2 cells can be
[created](https://r-spatial.github.io/s2/reference/s2_cell.html#ref-examples)
using their character string representation, or by specifying latitude
and longitude coordinates; e.g.:

``` r
s2::s2_lnglat(c(-84.4126, -84.5036), c(39.1582, 39.2875)) |> s2::as_s2_cell()
#> <s2_cell[2]>
#> [1] 8841ad122d9774a7 88404ebdac3ea7d1
```

## Start and stop dates example

Translate start and stop dates representing a range of days into a
list-col of days within each range:

``` r
tibble::tribble(
  ~s2, ~start_date, ~end_date,
  "8841b39a7c46e25f", "2023-02-20", "2023-04-01",
  "8841a45555555555", "2021-12-30", "2022-01-10"
) |>
  dplyr::mutate(
    s2 = s2::as_s2_cell(s2),
    dates = purrr::map2(
      as.Date(start_date), as.Date(end_date),
      \(.s, .e) seq(from = .s, to = .e, by = 1)
    ),
    pm25 = appc::predict_pm25(s2, dates)
  )
#> # A tibble: 2 × 5
#>   s2               start_date end_date   dates       pm25             
#>   <s2cell>         <chr>      <chr>      <list>      <named list>     
#> 1 8841b39a7c46e25f 2023-02-20 2023-04-01 <date [41]> <tibble [41 × 2]>
#> 2 8841a45555555555 2021-12-30 2022-01-10 <date [12]> <tibble [12 × 2]>
```

## Geomarker Assessment

Spatiotemporal geomarkers are used for predicting air pollution
concentrations, but also serve as exposures or confounding exposures
themselves. View information and options about each geomarker:

| geomarker                             | appc function                |
|---------------------------------------|------------------------------|
| 🌦 weather & atmospheric conditions    | `get_narr_data()`            |
| 🛰 satellite-based aerosol diagnostics | `get_merra_data()`           |
| 🚍 traffic densities                  | `get_traffic_summary()`      |
| 🏙 urban imperviousness                | `get_urban_imperviousness()` |
| 🔥 wildfire smoke                     | `install_smoke_pm_data()`    |
| 🏭 industrial emissions               | `get_nei_point_summary()`    |
| 🗻 elevation                          | `get_elevation_summary()`    |
| 🔗 census tract identifier            | `get_census_tract_id()`      |

## Developing

> Please note that the appc project is released with a [Contributor Code
> of Conduct](http://geomarker.io/appc/CODE_OF_CONDUCT.html). By
> contributing to this project, you agree to abide by its terms.

To create and release geomarker data for release assets, as well as to
create the AQS training data, train, and evaluate a generalized random
forest model, use [`just`](https://just.systems/man/en/) to execute
recipes in the `justfile`.

``` sh
> just --list

Available recipes:
    create_report        # create CV accuracy report
    dl_geomarker_data    # download all geomarker ahead of time, if not already cached
    docker_test          # run tests without cached release files
    docker_tool          # build docker image preloaded with {appc} and data
    release_merra_data   # upload merra data to github release
    release_model        # upload grf model to current github release
    release_nei_data     # install nei data from source and upload to github release
    release_smoke_data   # install smoke data from source and upload to github release
    release_traffic_data # install traffic data from source and upload to github release
    release_urban_imperviousness_data # install nlcd urban imperviousness data from source and upload to github release
    train_model          # train grf model
```
