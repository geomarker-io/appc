# Air Pollution Prediction Commons

<!-- badges: start -->
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/appc)](https://CRAN.R-project.org/package=appc)
  <!-- badges: end -->

## About

The goal of the {appc} package is to provide daily, high resolution, near real-time model-based ambient air pollution exposure assessments.
This is achieved by training a generalized random forest on several geomarkers to predict daily average EPA AQS concentrations from 2017 until the present. The {appc} package contains functions for generating geomarker predictors and the ambient air pollution concentrations. Source files included with the package create a training dataset, train the model, and create a cross-validation accuracy report.
Installed geomarker data sources and the grf model are hosted as release assets on GitHub, so the package can be used for quick geomarker assessment, including prediction of ambient air pollution concentrations at exact s2 locations on specific dates.

```r
# show short example of air pollution exposure assessment
```
### s2 locations

about using s2 to define location

### describe input format for predict_pm25 and show example

longer example where we convert start date and end date into a list of dates and put in a tibble to define new column of pm25 and pm25_se

### Exposure Assessment Model Details

- Exact s2 location, contiguous United States
- Daily, 2017 - 2023
- summarize predictors used
- add model statement on overall accuracy?

## Geomarker assessment

Cover individual geomarker examples? vignette??

## Developing

To create and release geomarker data for release assets, as well as to create the AQS training data, train, and evaluate a generalized random forest model, use [`just`](https://just.systems/man/en/) to execute recipes in the `justfile`.

```sh
> just --list

Available recipes:
    model_refresh        # data > train > report
    dl_geomarker_data    # download all geomarker ahead of time, if not already cached
    make_training_data   # make training data
    train                # train grf model
    report               # create CV accuracy report
    release_grf          # upload grf model to current github release
    docker_test          # run tests without cached release files
    docker_tool          # build docker image preloaded with {appc} and data
    release_merra_data   # upload merra data to github release
    release_nei_data     # install nei data from source and upload to github release
    release_smoke_data   # install smoke data from source and upload to github release
    release_traffic_data # install traffic data from source and upload to github release
    release_urban_imperviousness_data # install nlcd urban imperviousness data from source and upload to github release
```
