
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Air Pollution Prediction Commons

<!-- badges: start -->

[![R-CMD-check](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml)
[![r-universe](https://r-lib.r-universe.dev/badges/cpp11)](https://geomarker-io.r-universe.dev/appc)
[![CRAN
status](https://www.r-pkg.org/badges/version/appc)](https://CRAN.R-project.org/package=appc)
[![Lifecycle:
stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
<!-- badges: end -->

## About

The goal of the appc package is to provide daily, high resolution, near
real-time, model-based ambient air pollution exposure assessments. This
is achieved by training a generalized random forest on several
geomarkers to predict daily average EPA AQS concentrations from 2017
until the present at exact locations across the contiguous United States
(see `vignette("cv-model-performance")` for more details). The appc
package contains functions for generating geomarker predictors and the
ambient air pollution concentrations. Predictor geomarkers include
weather and atmospheric information, wildfire smoke plumes, elevation,
and satellite-based aerosol diagnostics products. Source files included
with the package train and evaluate models that can be updated with any
release to use more recent AQS measurements and/or geomarker predictors.

## Installing

Install the latest stable release of appc from R-universe with:

``` r
install.packages("appc", repos = c("https://geomarker-io.r-universe.dev", "https://cloud.r-project.org"))
```

Install the latest, under-development version of appc from GitHub with:

``` r
# install.packages("remotes")
remotes::install_github("geomarker-io/appc")
```

## Example

In R, create model-based predictions of ambient air pollution
concentrations at exact locations on specific dates using the
`predict_pm25()` function:

``` r
appc::predict_pm25(
  x = s2::as_s2_cell(c("8841b39a7c46e25f", "8841a45555555555")),
  dates = list(as.Date(c("2024-05-18", "2024-06-10")), as.Date(c("2023-06-22", "2023-08-15")))
)
#> ℹ (down)loading random forest model
#> ✔ (down)loading random forest model [9.2s]
#> 
#> ℹ checking that s2 are within the contiguous US
#> ✔ checking that s2 are within the contiguous US [62ms]
#> 
#> ℹ adding coordinates
#> ✔ adding coordinates [2.3s]
#> 
#> ℹ adding elevation
#> ✔ adding elevation [1.4s]
#> 
#> ℹ adding HMS smoke data
#> ✔ adding HMS smoke data [985ms]
#> 
#> ℹ adding NARR
#> ✔ adding NARR [880ms]
#> 
#> ℹ adding gridMET
#> ✔ adding gridMET [811ms]
#> 
#> ℹ adding NLCD
#> ! 2024 NLCD not yet available; using 2023
#> ℹ adding NLCD✔ adding NLCD [48ms]
#> 
#> ℹ adding MERRA
#> ✔ adding MERRA [1.2s]
#> 
#> ℹ adding time components
#> ✔ adding time components [24ms]
#> [[1]]
#> # A tibble: 2 × 2
#>    pm25 pm25_se
#>   <dbl>   <dbl>
#> 1  7.11   0.577
#> 2  5.93   0.636
#> 
#> [[2]]
#> # A tibble: 2 × 2
#>    pm25 pm25_se
#>   <dbl>   <dbl>
#> 1  5.20    1.82
#> 2  5.56    1.04
```

Installed geomarker data sources and the grf model are hosted as release
assets on GitHub and are downloaded locally to the package-specific R
user data directory (i.e., `tools::R_user_dir("appc", "data")`). These
files are cached across all of an R user’s sessions and projects.
(Specify an alternative download location by setting the
`R_USER_DATA_DIR` environment variable; see `?tools::R_user_dir`.)

See more examples in `vignette("timeline-example")`.

## S2 Geometry

The [S2Geometry](https://s2geometry.io/) library is a
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

## Geomarker Assessment

Spatiotemporal geomarkers are used for predicting air pollution
concentrations, but also serve as exposures or confounding exposures
themselves. View information and options about each geomarker:

| geomarker | appc function |
|----|----|
| 🌦 weather & atmospheric conditions | `get_gridmet_data()`, `get_narr_data()` |
| 🛰 satellite-based aerosol diagnostics | `get_merra_data()` |
| 🔥 wildfire smoke | `get_hms_smoke_data()` |
| 🗻 elevation | `get_elevation_summary()` |
| 🏙 land cover | `get_urban_imperv()` |

Currently, `get_urban_imperviousness()`, `get_traffic()`, and
`get_nei_point_summary()` are stashed in the `/inst` folder and are not
integrated into this package.

## Developing

> Please note that the appc project is released with a [Contributor Code
> of Conduct](http://geomarker.io/appc/CODE_OF_CONDUCT.html). By
> contributing to this project, you agree to abide by its terms.

To create and release geomarker data for release assets, as well as to
create the AQS training data, train, and evaluate a generalized random
forest model, install and use [`just`](https://just.systems/man/en/) to
execute recipes in the `justfile`.
