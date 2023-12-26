#' installs traffic data into user's data directory for the `appc` package
#' @references https://www.fhwa.dot.gov/policyinformation/hpms.cfm
install_traffic <- function() {
  # TODO other years???
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), "hpms_2017.gpkg")
  if (file.exists(dest_file)) return(dest_file)
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
      shQuote(dest_file),
      grep(".shp$", the_files, value = TRUE),
      "-nlt MULTILINESTRING",
      "National_Arterial2017"
    )
  )
  return(hpms_file_path)
}


#' get traffic summary data
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return a data.frame with one row for each s2 cell in `x` and one numeric column per traffic summaries
#' @details The `aadt_m_truck` is calculated as the sum of total average
#' annual daily truck-meters (AADT m) within 400 m of the s2 cell. Similarly,
#' `aadt_m_nontruck` is calculated by subtracting the summary measure for all
#' trucks from the summary measure for all traffic.
get_traffic_summary <- function(x, buffer = 400) {
  d_aadt <-
    install_traffic() |>
    sf::st_read() |>
    dplyr::transmute(route_id = Route_ID,
                     s2_geography = s2::as_s2_geography(geom),
                     aadt_total = AADT,
                     aadt_truck = AADT_SINGL + AADT_COMBI) |>
    tibble::as_tibble() |>
    dplyr::select(-geom)
  # TODO, it would be fast to breakup the aadt geometries by s2 level 3 ahead of time during the install??
  # parentize to map over intersection with aadt geometry
  d <-
    tibble::tibble(s2 = unique(x)) |>
    dplyr::mutate(s2_geography = s2::as_s2_geography(s2::s2_cell_to_lnglat(s2))) |>
    dplyr::nest_by(s2_4 = s2::s2_cell_parent(s2, level = 4)) |>
    dplyr::ungroup()
  subset_within <- function(chnk, distance = 400) {
    x_aadt_intersection <- 
      s2::s2_intersects_box(x = d_aadt$s2_geography,
                        lng1 = min(s2::s2_x(chnk$s2_geography)),
                        lat1 = min(s2::s2_y(chnk$s2_geography)),
                        lng2 = max(s2::s2_x(chnk$s2_geography)),
                        lat2 = max(s2::s2_y(chnk$s2_geography)))
    s2::s2_dwithin_matrix(chnk$s2_geography, dplyr::filter(d_aadt, x_aadt_intersection)$s2_geography, distance = distance)
  }
  d$withins <- purrr::map(d$data, subset_within, .progress = "intersecting with AADT")
  d <- d |> tidyr::unnest(cols = c(data, withins))
  # summarize intersecting data using within integers
  summarize_traffic <- function(x_withins) {
    d_aadt[x_withins, ] |>
      dplyr::summarize(
        aadt_m_truck = sum(s2::s2_length(s2_geography) * aadt_truck),
        aadt_m_nontruck = sum(s2::s2_length(s2_geography) * (aadt_total - aadt_truck))
      )
  }
  d$aadt <- purrr::map(d$withins, summarize_traffic, .progress = "summarizing traffic")
  traffic_summaries <-
    d |>
    dplyr::select(s2, aadt) |>
    tidyr::unnest(cols = c(aadt))
  output <-
    tibble::tibble(s2 = x) |>
    dplyr::left_join(traffic_summaries, by = "s2") |>
    select(-s2)
  return(output)
}

library(dplyr)

d <-
  readRDS("data/aqs.rds") |>
  dplyr::distinct(s2)

out <- dplyr::bind_cols(d, get_traffic_summary(d$s2))

saveRDS(out, "data/traffic.rds")
