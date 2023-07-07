"https://daac.ornl.gov/daacdata/daymet/Daymet_Daily_V4R1/data/daymet_v4_daily_na_dayl_2018.nc" |>
  download.file("test.nc")

parameters <- c("prcp", "tmax", "tmin", "vp")

# need to get hpbl still?

"daymet_v4_daily_na_{parameter}_{year}.nc"
