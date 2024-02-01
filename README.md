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
    check                # check R package
    document             # document R package
    make_training_data   # make training data
    train                # train grf model
    upload_training_data # upload training data to S3
```

### Installing training data

Instead of using the appc functions to make training data (`just make_training_data`), download a pregenerated version in R using the `fs::path_package()` function to download the file to the installed `appc` package:

```R
download.file(url = "https://geomarker-io.s3-us-east-2.amazonaws.com/appc/training_data_0.1.0.rds",
              destfile = fs::path(fs::path_package("appc"), "training_data.rds"))
```

	
