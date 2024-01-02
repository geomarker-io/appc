# Air Pollution Prediction Commons

<!-- badges: start -->
  [![R-CMD-check](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/geomarker-io/appc/actions/workflows/R-CMD-check.yaml)
  <!-- badges: end -->
 
## Air pollution exposure assessment in R

```R
library(appc)
```

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

## things to be done

- [ ] add just target for downloading/installing required geomarker data sources (w/o running any geomarker assessment code)
- [ ] add "convolution layers" of AQS data
- [ ] add small section about just and using it to run commands in the repository
- [ ] add separate models for other pollutants
  - alter NEI emissions predictors for these pollutants?
- [ ] create Rmd report for cross validation figures, tables
  - double check data pipeline (missingness, summary statistics)
  - use OOB predictions to create CV error estimations, pred vs obs scatter plots (both in bag and out of bag by space)
  - include prediction tests for random locations and tests (but with fixed seed)
  - test for reasonable prediction magnitude, mean and var of preds across time and space
  - describe differences between test predictions for different model releases
- [ ] translate to a runnable 'thing' (SALT? GHA?)
- [ ] build user prediction tools, API
  - add data tests for prediction outputs (reasonable prediction magnitude?)
  - version the api and prediction tool with {appc}

## coverage

- Contiguous United States
- daily, 2016 - 2022, but updated semi-annually at a ? lag
  - pickup off of other models and be more useful for recent EHR and registry data
  - low-latency exposure estimates for major air pollutants are a recognized need

Instead of creating a spatiotemporal grid of predictors, create prediction model for set of input points and reuse code to derive features and predict on new input data.

- [x] AQS average daily monitoring stations
  - [ ] convolution layers of AQS data
  - [x] derived data: coordinates, day of year, etc.
- [x] NARR
- [x] NLCD `pct_imperviousness` and `pct_treecanopy`
- [x] PRISM elevation data @ 800 m resolution https://prism.oregonstate.edu/normals/
- [x] census tract identifier
- [x] PM smoke census tract product
- [x] National Emissions Inventory
- [ ] fire inventory from NCAR https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar ??
- [ ] AOD ([AWS COGs](https://www.earthdata.nasa.gov/engage/cloud-optimized-geotiffs#AOD) don't have complete temporal coverage)
- [ ] non-point sources from NEI?


has monitoring gotten better?  (older pub saw better performance in later years) is this why this simple model looks good -- just 2016 - current?

exposure assessment code (must be in R package, but geocoding can be outside R)

make the entire training pipeline an R package?  then same functions used for prediction data too... (intermediate data functions would be good covariates / other geomarkers to use as well)

test users for deriving exposure estimates: Clara, Kelly, Yang, Stephen

### air pollution predictor functions

`install_{geomarker}_data()` functions (e.g., `install_smoke_data()`, `install_elevation_data()`) downloads geomarker data files directly from the provider and stores them as harmonized files in the R user data directory for the `appc` package.  This allows for reference of the geomarker data files across R sessions and projects. These functions are utilized automatically by the geomarker assessment functions, but can be called without input data to install the geomarker data ahead of time, if external internet access is not possible after input data is added. *Note that some of the install functions require a system installation of `gdal`.* 


`get_{geomarker}_summary()` functions (e.g., `get_narr_data()`, `get_census_tract_id()` take a vector of `s2` geographic cell identifers and a list of date vectors. Each item in the list of date vectors corresponds to one of the `s2` cell identifiers in the vector and can contain multiple dates.

TODO Each `get_` geomarker summary function has a `XXX` argument specifying the path to the geomarker data file.  This defaults to using the `install_` geomarker function, but can be set to use existing geomarker data files (e.g., on a shared storage drive, across compute nodes on a high performance cluster).

```R
get_elevation_data(data_source = "/scratch/broeg1/appc/")
```

TODO if providing a directory, the specific geomarker data file will be searched for in that directory.

e.g.,

```R
get_narr_data(data_source = "/scratch/broeg1/appc")
```
