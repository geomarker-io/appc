# Air Pollution Prediction Commons

- Contiguous United States
- daily, 2016 - 2022, but updated semi-annually at a ? lag
  - pickup off of other models and be more useful for recent EHR and registry data
  - low-latency exposure estimates for major air pollutants are a recognized need

Instead of creating a spatiotemporal grid of predictors, create prediction model for set of input points and reuse code to derive features and predict on new input data.

- [x] AQS average daily monitoring stations
  - [ ] convolution layers of AQS data??
  - [x] derived data: coordinates, day of year, etc.
- [x] NARR
- [x] NLCD `pct_imperviousness` and `pct_treecanopy`
- [x] PRISM elevation data @ 800 m resolution https://prism.oregonstate.edu/normals/
- [x] census tract identifier
- [x] PM smoke census tract product
- [ ] National Emissions Inventory
- [ ] fire inventory from NCAR https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar ??
- [ ] AOD ([AWS COGs](https://www.earthdata.nasa.gov/engage/cloud-optimized-geotiffs#AOD) don't have complete temporal coverage)


has monitoring gotten better?  (older pub saw better performance in later years) is this why this simple model looks good -- just 2016 - current?

exposure assessment code (must be in R package, but geocoding can be outside R)

make the entire training pipeline an R package?  then same functions used for prediction data too... (intermediate data functions would be good covariates / other geomarkers to use as well)

test users for deriving exposure estimates: Clara, Kelly, Yang, Stephen
