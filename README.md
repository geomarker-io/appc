# Air Pollution Prediction Commons

<!-- badges: start -->
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/appc)](https://CRAN.R-project.org/package=appc)
  <!-- badges: end -->
 
## Air pollution exposure assessment in R

### Use R to assess air pollution exposure

1. A vector of `s2` geohashes
2. A list of date vectors, one for each geohash

```R
library(appc)
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
