#' Get traffic summary
#'
#' Highway Performance Monitoring System (HPMS) data from 2020 is summarized as the average daily total number of meters driven by
#' passenger vehicles, trucks/busses, and tractor-trailers on interstates, freeways, and expressways
#' within `buffer` meters of each s2 cell
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param buffer distance from s2 cell (in meters) to summarize data
#' @return a list the same length as `x`, which each element having a numeric vector of
#' `aadtm_passenger`, `aadtm_trucks_buses`, `aadtm_tractor_trailer`
#' @details
#' Only roads with F_SYSTEM classification of 1 ("interstate") or 2 ("principal arterial - other freeways and expressways")
#' are used. Passenger vehicles (FHWA 1-3) are calculated as the total minus FHWA class 4-7 (single unit) and 8-13 (combo)
#' @references <https://www.fhwa.dot.gov/policyinformation/hpms.cfm>
#' @references <https://data-usdot.opendata.arcgis.com/datasets/usdot::highway-performance-monitoring-system-hpms-2020/about>
#' @export
#' @examples
#' get_traffic_summary(
#'   s2::as_s2_cell(c("8841b6abd8207619", "8841b4f6affffffb", "8841b39f07f7d899")))
#' \dontrun{
#' # randomly sample 100 level 18 cells from s2 level-9: 8841b4
#' # https://igorgatis.github.io/ws2/?cells=8841b4
#' # use their centroids as the level 30 s2 cells
#' set.seed(1)
#' my_s2_cells <-
#'   s2::s2_covering_cell_ids(s2::s2_cell_polygon(s2::as_s2_cell("8841b4")),
#'                            min_level = 18, max_level = 18) |>
#'   unlist()|>
#'   sample(size = 100)|>
#'   s2::s2_cell_center()|>
#'   s2::as_s2_cell()
#' get_traffic_summary(my_s2_cells) |>
#'   dplyr::bind_rows()
#' }
get_traffic_summary <- function(x, buffer = 400) {
  check_s2_dates(x)
  xx <- unique(x)

  cli::cli_progress_step("reading traffic data...")
  hpms <-
    sf::read_sf(install_traffic(), quiet = TRUE) |>
    dplyr::mutate(s2_geography = s2::as_s2_geography(geom)) |>
    sf::st_drop_geometry()

  cli::cli_progress_step("finding nearby roadways")
  x_withins <- purrr::map(
    s2::s2_cell_center(xx),
    \(x) {
      # cli::cli_progress_update(.envir = parent.frame(3))
      which(s2::s2_prepared_dwithin(hpms$s2_geography, x, distance = buffer))
    },
    .progress = list(
      format = "finding nearby roadways for {cli::pb_current} of {cli::pb_total} unique locations {cli::pb_eta_str}"
    )
  )

  cli::cli_progress_step("calculating length-based traffic-length totals")
  get_intersection_aadtm <- function(the_s2, the_s2_withins) {
    hpms_withins <- hpms[the_s2_withins, ]
    lengths <- s2::s2_intersection(
      hpms_withins$s2_geography,
      s2::s2_buffer_cells(s2::s2_cell_to_lnglat(the_s2), buffer)
    ) |>
      s2::s2_length()
    out <- c(
      aadtm_trucks_buses = sum(hpms_withins$AADT_SINGLE_UNIT * lengths),
      aadtm_tractor_trailer = sum(hpms_withins$AADT_COMBINATION * lengths),
      aadtm_passenger = with(
        hpms_withins,
        sum((AADT - AADT_SINGLE_UNIT - AADT_COMBINATION) * lengths)
      )
    )
    return(out)
  }

  aadtm <- purrr::pmap(
    list(the_s2 = xx, the_s2_withins = x_withins),
    get_intersection_aadtm
  )

  names(aadtm) <- xx
  return(aadtm[as.character(x)])
}

#' `install_traffic()` installs pacakge released traffic data into user's data directory for the `appc` package
#' @param traffic_release name of github release to download traffic data file from
#' @rdname get_traffic_summary
#' @export
install_traffic <- function(traffic_release = "hpms_2020_f12_aadt-2025-07-16") {
  out_path <- fs::path(
    tools::R_user_dir("appc", "data"),
    "hpms_2020_f12_aadt",
    ext = "gpkg"
  )
  if (file.exists(out_path)) {
    return(out_path)
  }
  dl_url <- glue::glue(
    "https://github.com",
    "geomarker-io",
    "appc",
    "releases",
    "download",
    traffic_release,
    "hpms_2020_f12_aadt.gpkg",
    .sep = "/"
  )
  utils::download.file(dl_url, out_path, quiet = FALSE, mode = "wb")
  return(as.character(out_path))
}
