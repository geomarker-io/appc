

## "https://www.earthdata.nasa.gov/engage/cloud-optimized-geotiffs#VI"
## only covers 2018-01 to 2022-05 ???

download.file(
  "https://e4ftl01.cr.usgs.gov/MOTA/MCD19A2.061/2023.07.05/MCD19A2.A2023186.h08v04.061.2023191172829.hdf",
  destfile = "example_file.hdf",
    method = "wget",
    extra = c(
      "--continue",
      "--user=brokamrc",
      "--password=8u3wtE}RYGp3/Ux8"
    )
  )

download.file(
  "https://e4ftl01.cr.usgs.gov/MOTA/MCD19A2.061/2023.07.05/MCD19A2.A2023186.h08v04.061.2023191172829.hdf.xml",
  destfile = "example_file.hdf.xml",
    method = "wget",
    extra = c(
      "--continue",
      "--user=brokamrc",
      "--password=8u3wtE}RYGp3/Ux8"
    )
  )

system2("gdal_translate", c("-of COG", "example_file.hdf", "example_file.tif"))
          
