library(dplyr)
library(s2)
library(terra)
dir.create(tools::R_user_dir("s3", "data"), showWarnings = FALSE, recursive = TRUE)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  distinct(s2) |>
  mutate(s2_geography = s2_buffer_cells(as_s2_geography(s2_cell_to_lnglat(s2)), distance = 400))
d_vect <- vect(s2_as_text(d$s2_geography), crs = "epsg:4326")
d_vect$s2 <- d$s2

# highway performance monitoring system data
# https://www.fhwa.dot.gov/policyinformation/hpms.cfm
# downloads to R_user_dir
## fs::dir_info(tools::R_user_dir("s3", "data"), recurse = TRUE)
get_traffic <- function() {
  hpms_file_path <- fs::path(tools::R_user_dir("s3", "data"), "hpms_2016.gpkg")
  if (file.exists(hpms_file_path)) {
    return(hpms_file_path)
  }
  message("downloading HPMS data")
  tf <- tempfile(fileext = ".zip")
  httr::GET("https://www.bts.gov/sites/bts.dot.gov/files/ntad/HPMS2016.gdb.zip", 
            httr::write_disk(tf, overwrite = TRUE),
            httr::progress())
  unzip(tf, exdir = tempdir())
  message("converting HPMS data")
  system2(
    "ogr2ogr",
    c("-f GPKG",
      "-progress",
      "-makevalid",
      "-where = ",
      shQuote(hpms_file_path),
      fs::path(tempdir(), "2016.gdb"),
      "HPMS2016")
  )
  return(hpms_file_path)
}

"https://www.fhwa.dot.gov/policyinformation/hpms/shapefiles_nationalarterial2017.zip"

d_traffic <-
  get_traffic() |>
  sf::st_read() |>
  mutate(s2_geography = as_s2_geography(geometry)) |>
  tibble::as_tibble() |>
  select(-geometry)

s2_tracts <- function(state,  year = 2019) {
  tigris::tracts(state = state, year = year, progress_bar = FALSE, keep_zipped_shapefile = TRUE) |>
    mutate(s2_geography = as_s2_geography(geometry)) |>
    tibble::as_tibble() |>
    select(-geometry)
}

sf::st_read(get_traffic()) |>
  



s2::s2_read(hpms_file_path)
sf::st_read(hpms_file_path)
