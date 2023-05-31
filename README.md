# Air Pollution Prediction Commons

- daily
  - 2000 - current
- h3 resolution 7
  - ~ 1.74 million cells in contiguous US
  - each ~ 5 km sq (`h3::hex_area()`)
  
- s2 instead: https://r-spatial.github.io/s2/index.html

- [ ] AQS average daily monitoring stations
  - [ ] convolution layers of AQS data over time harmonized to h3
  - [ ] derived data: coordinates, day of year, etc.
- [ ] satellite based measures of aerosol, NO2, VI (AWS S3 COGs)
- [ ] landcover
- [ ] PRISM elevation data @ 800 m resolution https://prism.oregonstate.edu/normals/
- [ ] National Emissions Inventory
- [ ] climate and meteorology
  - [ ] PRISM climate data (precipitation, mean temperature, max temperature, min temperature, VPD max, VPD min)
  - [ ] still use NARR for wind and HPBL?
- [ ] NLCD data? or would VI cover it...?
- [ ] fire inventory from NCAR https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
