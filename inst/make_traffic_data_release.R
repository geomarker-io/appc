library(sf)
library(s2)
library(dplyr, warn.conflicts = FALSE)

traffic_release_name <- "hpms_f123_aadt"
traffic_release_date <- Sys.Date()

# download open HPMS geodatabase from arcgis:
# https://www.arcgis.com/home/item.html?id=75f897d0151b409baea47a0f3544b75e
# 5+ GB (!)
download.file(
  "https://www.arcgis.com/sharing/rest/content/items/c199f2799b724ffbacf4cafe3ee03e55/data",
  "~/Downloads/HPMS_2020.gdb.zip"
)
unzip("~/Downloads/HPMS_2020.gdb.zip", exdir = "~/Downloads")

gdb_path <- "~/Downloads/HPMS_2020"
# using f_system of 1 or 2 would be all "interstates, freeways, and expressways"
# F_SYSTEM: functional classification system:
#   - 1: interstate
#   - 2: principal arterial - other freeways and expressways
#   - 3: principal arterial - other

# AADT: FHWA 1-13
# AADT_SINGLE_UNIT; aadt_trucks_buses: single-unit trucks and buses (FHWA 4-7)
# AADT_COMBINATION; aadt_tractor_trailer: combination trucks (FHWA 8-13)
# aadt_passenger: passenger (FHWA 1-3; AADT - AADT_SINGLE_UNIT - AADT_COMBINATION)

hpms_states <-
  st_layers(dsn = gdb_path)$name |>
  strsplit("_", fixed = TRUE) |>
  purrr::map_chr(3)

hpms_state <- "OH"

hpms_state_d <-
  st_read(
    dsn = gdb_path,
    query = glue::glue(
      "SELECT County_Code, Route_ID, AADT, AADT_SINGLE_UNIT, AADT_COMBINATION",
      "FROM HPMS_FULL_{hpms_state}_2020",
      "WHERE F_SYSTEM IN ('1', '2')",
      .sep = " "
    ),
    quiet = TRUE
  ) |>
  na.omit() |>
  st_zm() |>
  tibble::as_tibble() |>
  # filter(Route_ID == "SHAMIR00075**C") |>
  # filter(County_Code == 61) |>
  st_as_sf() |>
  st_transform(5072)

target_lvl <- 16

hpms_state_d$s2_covering_cells_buffer <-
  s2_covering_cell_ids(
    as_s2_geography(st_buffer(hpms_state_d$Shape, dist = 400)),
    min_level = target_lvl,
    max_level = target_lvl,
    max_cells = 1000
  )

state_aadt_s2_target_lvl <-
  hpms_state_d |>
  st_drop_geometry() |>
  tibble::as_tibble() |>
  rowwise() |>
  mutate(
    s2_cell = list(as.character(unlist(s2_covering_cells_buffer))),
    .keep = "unused"
  ) |>
  tidyr::unnest(s2_cell) |>
  summarize(
    aadt_trucks_buses = mean(AADT_SINGLE_UNIT),
    aadt_tractor_trailer = mean(AADT_COMBINATION),
    aadt_passenger = mean(AADT) - aadt_trucks_buses - aadt_tractor_trailer,
    .by = "s2_cell"
  ) |>
  mutate(s2_cell = as_s2_cell(s2_cell))

tibble::tibble(
  s2_geography = s2::s2_cell_polygon(as_s2_cell(
    state_aadt_s2_target_lvl$s2_cell
  )),
  aadt = state_aadt_s2_target_lvl$aadt_passenger
) |>
  sf::st_as_sf() |>
  mapview::mapview(zcol = "aadt")
# mapview::mapview(st_as_sf(hpms_state_d), zcol = "AADT")

s2_distance(
  as_s2_geography(s2_cell_to_lnglat(state_aadt_s2_target_lvl$s2_cell)),
  s2_union_agg(as_s2_geography(hpms_state_d$Shape))
)

# next: for query points, calculate level 21 s2 cell id and find cells within a buffer distance of point; then, design fast lookup process for s2 cell id at level 21 to table of aadt info and use to create averages of buffered inputs ......???

tmp <-
  sf::st_read(
    dsn = gdb_path,
    query = glue::glue(
      "SELECT F_SYSTEM, AADT, AADT_SINGLE_UNIT, AADT_COMBINATION",
      "FROM HPMS_FULL_{hpms_state}_2020",
      "WHERE F_SYSTEM IN ('1', '2')",
      .sep = " "
    )
  ) |>
  sf::st_zm() |>
  dplyr::mutate(
    s2_geography = s2::as_s2_geography(Shape)
  ) |>
  sf::st_drop_geometry() |>
  tibble::as_tibble()


state <- "39"

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
  # out$s2_geography <- NULL
  return(out)
}

hpms_pa_aadt <- purrr::map(
  hpms_states,
  extract_F123_AADT,
  .progress = "extracting state F123 AADT files"
)

out <- dplyr::bind_rows(hpms_pa_aadt)
