# Air Pollution Prediction Commons

<!-- badges: start -->
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/appc)](https://CRAN.R-project.org/package=appc)
  <!-- badges: end -->
 
## Air pollution exposure assessment in R

`get_{geomarker}_summary()` functions (e.g., `get_narr_data()`, `get_census_tract_id()`) take a vector of `s2` geographic cell identifers (and sometimes a calendar year or a list of date vectors). If required, the `year` argument specifies the calendar year to be used for geomarker assessment. If `dates` are required, each item in the list of date vectors corresponds to one of the `s2` cell identifiers in the vector and can contain multiple dates.

```R
library(appc)
# get_census_tract_id(year = "2019")
# get_traffic_summary(x, buffer = 400)
# get_nei_point_summary(x, year = "2020", pollutant_code = "PM25-PRI", buffer = 1000)
# get_narr_data(x, dates, narr_var = "air.2m")
# get_nlcd_summary(x, "treecanopy", buffer = 750)
```

### Exposure Assessment Model Details

- Exact s2 location, contiguous United States
- Daily, 2017 - 2023

## Developing

Use [`just`](https://just.systems/man/en/); e.g., `just --list`:

```sh
Available recipes:
    build_site         # build documentation website
    check              # check R package
    document           # document R package
    make_training_data # make training data
    report             # create CV accuracy report
    train              # train grf model
    upload_geo_data    # upload precomputed geomarker data to current github release
    upload_grf         # upload grf model to current github release
```
