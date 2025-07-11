#' Get traffic summary
#'
#' Highway Performance Monitoring System (HPMS) data from 2020 is summarized as the sum of the total (and truck-only) average annual daily vehicle-meter counts within `buffer` meters of each s2 geohash.
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @param s2_approx_level the level of approximation used for geospatial intersections, see details
#' @return a list the same length as `x`, which each element having a list of `total_aadt_m` and `truck_aadt_m` estimates
#' @details By default, an s2 level 14 approximation (~ 521 m sq) is used to simplify the intersection calculation with
#' traffic summary data. The median areas of the s2 cells in the contiguous United States by s2 level is
#' 16: 130 m sq, 15: 260 m sq, 14: 521 m sq.
#' @references <https://www.fhwa.dot.gov/policyinformation/hpms.cfm>
#' @references <https://data-usdot.opendata.arcgis.com/datasets/usdot::highway-performance-monitoring-system-hpms-2020/about>
#' @references <https://www.fhwa.dot.gov/policyinformation/hpms/fieldmanual/hpms_field_manual_dec2016.pdf>
#' @export
#' @examples
#' get_traffic_summary(
#'   s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")),
#'   buffer = 1500)
get_traffic_summary <- function(
  x,
  buffer = 400,
  s2_approx_level = c("14", "15", "16")
) {
  check_s2_dates(x)
  s2_approx_level <- rlang::arg_match(s2_approx_level)
  aadt_data <-
    readRDS(install_traffic()) |>
    dplyr::transmute(
      s2_centroid,
      length,
      aadt_total = AADT,
      aadt_truck = sum(
        AADT_SINGLE_UNIT,
        AADT_COMBINATION,
        na.rm = TRUE
      )
    ) |>
    dplyr::group_by(
      s2_parent = s2::s2_cell_parent(
        s2_centroid,
        level = as.numeric(s2_approx_level)
      )
    ) |>
    dplyr::summarize(
      aadt_total_m = sum(aadt_total * length, na.rm = TRUE),
      aadt_truck_m = sum(aadt_truck * length, na.rm = TRUE)
    )
  xx <- unique(x)
  withins <- s2::s2_dwithin_matrix(
    s2::s2_cell_to_lnglat(xx),
    s2::s2_cell_to_lnglat(aadt_data$s2_parent),
    distance = buffer
  )
  summarize_traffic <- function(i) {
    aadt_data[withins[[i]], ] |>
      dplyr::summarize(
        aadt_total_m = sum(aadt_total_m),
        aadt_truck_m = sum(aadt_truck_m)
      ) |>
      as.list()
  }
  withins_aadt <- purrr::map(1:length(withins), summarize_traffic)
  names(withins_aadt) <- xx
  return(withins_aadt[as.character(x)])
}

#' `install_traffic()` installs traffic data into user's data directory for the `appc` package
#' @rdname get_traffic_summary
#' @export
install_traffic <- function() {
  out_path <- fs::path(
    tools::R_user_dir("appc", "data"),
    "hpms_f123_aadt",
    ext = "rds"
  )
  if (file.exists(out_path)) {
    return(out_path)
  }
  if (!install_source_preference()) {
    install_released_data(released_data_name = "hpms_f123_aadt.rds")
    return(as.character(out_path))
  }
  message("downloading and installing HPMS data from source")
  dest_path <- tempfile(fileext = ".gdb.zip")
  "https://www.arcgis.com/sharing/rest/content/items/c199f2799b724ffbacf4cafe3ee03e55/data" |>
    utils::download.file(dest_path, mode = "wb")
  hpms_states <-
    sf::st_layers(dsn = dest_path)$name |>
    strsplit("_", fixed = TRUE) |>
    purrr::map_chr(3)
  extract_F123_AADT <- function(state) {
    out <-
      sf::st_read(
        dsn = dest_path,
        query = glue::glue(
          "SELECT F_SYSTEM, AADT, AADT_SINGLE_UNIT, AADT_COMBINATION",
          "FROM HPMS_FULL_{state}_2020",
          "WHERE F_SYSTEM IN ('1', '2', '3')",
          .sep = " "
        ),
        quiet = TRUE
      ) |>
      sf::st_zm() |>
      dplyr::mutate(
        s2_geography = s2::as_s2_geography(Shape)
      ) |>
      sf::st_drop_geometry() |>
      tibble::as_tibble()
    out$length <- s2::s2_length(out$s2_geography)
    out$s2_centroid <- purrr::map_vec(
      out$s2_geography,
      \(x) s2::as_s2_cell(s2::s2_centroid(x)),
      .ptype = s2::s2_cell()
    )
    out$s2_geography <- NULL
    return(out)
  }
  hpms_pa_aadt <- purrr::map(
    hpms_states,
    extract_F123_AADT,
    .progress = "extracting state F123 AADT files"
  )
  out <- dplyr::bind_rows(hpms_pa_aadt)
  saveRDS(out, out_path)
  return(as.character(out_path))
}
