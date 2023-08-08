library(dplyr)
library(s2)
library(terra)
dir.create(tools::R_user_dir("s3", "data"), showWarnings = FALSE, recursive = TRUE)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  distinct(s2) |>
  mutate(s2_geography = as_s2_geography(s2_cell_to_lnglat(s2)))
  ## mutate(s2_geography = s2_buffer_cells(as_s2_geography(s2_cell_to_lnglat(s2)), distance = 400))

## d_vect <- vect(s2_as_text(d$s2_geography), crs = "epsg:4326")
## d_vect$s2 <- d$s2

# highway performance monitoring system data
# https://www.fhwa.dot.gov/policyinformation/hpms.cfm
# downloads to R_user_dir
## fs::dir_info(tools::R_user_dir("s3", "data"), recurse = TRUE)
get_traffic <- function() {
  hpms_file_path <- fs::path(tools::R_user_dir("s3", "data"), "hpms_2017.gpkg")
  if (file.exists(hpms_file_path)) {
    return(hpms_file_path)
  }
  message("downloading HPMS data")
  tf <- tempfile(fileext = ".zip")
  httr::GET("https://www.fhwa.dot.gov/policyinformation/hpms/shapefiles/nationalarterial2017.zip",
            httr::write_disk(tf, overwrite = TRUE),
            httr::progress())
  the_files <- unzip(tf, exdir = tempdir())
  message("converting HPMS data")
  system2(
    "ogr2ogr",
    c("-f GPKG",
      ## "-skipfailures",
      "-makevalid",
      "-progress",
      "-select Route_ID,AADT,AADT_SINGL,AADT_COMBI",
      shQuote(hpms_file_path),
      grep(".shp$", the_files, value = TRUE),
      "-nlt MULTILINESTRING",
      "National_Arterial2017")
  )
  return(hpms_file_path)
}

d_aadt <-
  get_traffic() |>
  sf::st_read() |>
  transmute(route_id = Route_ID,
            s2_geography = as_s2_geography(geom),
            aadt_total = AADT,
            aadt_truck = AADT_SINGL + AADT_COMBI) |>
  tibble::as_tibble() |>
  select(-geom)

tictoc::tic()
d <- d |>
  mutate(withins =  s2_dwithin_matrix(s2_geography, d_aadt$s2_geography, distance = 400))
tictoc::toc()
# 1262 seconds...

withins <- setNames(withins, d$s2)

s2_intersection(
  d_aadt[withins[[2]], "s2_geography", drop = TRUE],

  as_s2_geography(s2_cell_to_lnglat(as_s2_geography(names(withins)[2])))

setNames(withins, d$s2) |>
  purrr::compact() |>
  purrr::imap(\(x, idx)

withins[[2]]

s2_intersection(d$s2_geography[1], d_aadt$s2_geography)

mutate(s2_geography = as_s2_geography(s2_cell_to_lnglat(s2)))

d$intersections <- s2_intersects_matrix(d$s2_geography, d_aadt$s2_geography)

purrr::map2(d$s2_geography, d$intersections,
            \(geo, int) {
              s2_intersection(geo, int) |>
                s2_length()

              }

d


s2_plot(d[2, "s2_geography", drop = TRUE])
s2_plot(d_aadt[intersections[[2]][1], "s2_geography", drop = TRUE], add = TRUE, col = "gold")
s2_plot(d_aadt[intersections[[2]][2], "s2_geography", drop = TRUE], add = TRUE, col = "red")
s2_plot(d_aadt[intersections[[2]][3], "s2_geography", drop = TRUE], add = TRUE, col = "blue")
s2_plot(d_aadt[intersections[[2]][4], "s2_geography", drop = TRUE], add = TRUE, col = "forestgreen")


s2_plot(d[2, "s2_geography", drop = TRUE])
s2_intersection(
  d[2:3, "s2_geography", drop = TRUE],
  d_aadt[intersections[[2]], "s2_geography", drop = TRUE])

