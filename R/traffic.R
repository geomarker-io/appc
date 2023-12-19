library(dplyr)
library(s2)
library(terra)
dir.create(tools::R_user_dir("s3", "data"), showWarnings = FALSE, recursive = TRUE)

rd <- arrow::read_parquet("data/aqs.parquet")

d <-
  rd |>
  distinct(s2) |>
  mutate(s2_geography = as_s2_geography(s2_cell_to_lnglat(s2)))

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
  httr::GET(
    "https://www.fhwa.dot.gov/policyinformation/hpms/shapefiles/nationalarterial2017.zip",
    httr::write_disk(tf, overwrite = TRUE),
    httr::progress()
  )
  the_files <- unzip(tf, exdir = tempdir())
  message("converting HPMS data")
  system2(
    "ogr2ogr",
    c(
      "-f GPKG",
      "-skipfailures",
      "-makevalid",
      "-progress",
      "-select Route_ID,AADT,AADT_SINGL,AADT_COMBI",
      shQuote(hpms_file_path),
      grep(".shp$", the_files, value = TRUE),
      "-nlt MULTILINESTRING",
      "National_Arterial2017"
    )
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

# TODO, it would be fast to breakup the aadt geometries by s2 level 3 ahead of time
# parentize to map over intersection with aadt geometry
d <- d |>
  nest_by(s2_4 = s2::s2_cell_parent(s2, level = 4)) |>
  ungroup()
subset_within <- function(x, distance = 400) {
  x_aadt_intersection <- 
    s2_intersects_box(x = d_aadt$s2_geography,
                      lng1 = min(s2_x(x$s2_geography)),
                      lat1 = min(s2_y(x$s2_geography)),
                      lng2 = max(s2_x(x$s2_geography)),
                      lat2 = max(s2_y(x$s2_geography)))
  s2_dwithin_matrix(x$s2_geography, filter(d_aadt, x_aadt_intersection)$s2_geography, distance = distance)
}
d$withins <- purrr::map(d$data, subset_within, .progress = "intersecting with AADT")

d <- d |> tidyr::unnest(cols = c(data, withins))

# summarize intersecting data using within integers
summarize_traffic <- function(x_withins) {
  d_aadt[x_withins, ] |>
    summarize(
      aadt_m_truck = sum(s2_length(s2_geography) * aadt_truck),
      aadt_m_nontruck = sum(s2_length(s2_geography) * (aadt_total - aadt_truck))
    )
}
d$aadt <- purrr::map(d$withins, summarize_traffic, .progress = "summarizing traffic")

d <- d |>
  select(s2, aadt) |>
  tidyr::unnest(cols = c(aadt))


rd |>
  select(s2, pollutant) |>
  left_join(d, by = "s2") |>
  arrow::write_parquet("data/traffic.parquet")
