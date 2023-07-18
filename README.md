# Air Pollution Prediction Commons

- daily
  - 2010 - current
- s2 https://r-spatial.github.io/s2/index.html


Instead of creating a spatiotemporal grid of predictors, create prediction model for set of input points and reuse code to derive features and predict on new input data.

- [x] AQS average daily monitoring stations
  - [ ] convolution layers of AQS data??
  - [ ] derived data: coordinates, day of year, etc.
- [x] NARR
- [x] NLCD `pct_imperviousness` and `pct_treecanopy`
- [ ] [elevation](https://www.usgs.gov/news/technical-announcement/usgs-digital-elevation-models-dem-switching-new-distribution-format) 
- [ ] National Emissions Inventory
- [ ] AOD ([AWS COGs](https://www.earthdata.nasa.gov/engage/cloud-optimized-geotiffs#AOD) don't have complete temporal coverage)
- [ ] PRISM climate data (precipitation, mean temperature, max temperature, min temperature, VPD max, VPD min) ??
- [ ] PRISM elevation data @ 800 m resolution https://prism.oregonstate.edu/normals/
- [ ] fire inventory from NCAR https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
