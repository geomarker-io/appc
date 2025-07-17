library(sf)
library(s2)
library(dplyr, warn.conflicts = FALSE)

# download open HPMS geodatabase from arcgis:
# https://www.arcgis.com/home/item.html?id=75f897d0151b409baea47a0f3544b75e
# 5+ GB (!)
gdb_path <- "~/Downloads/HPMS_2020.gdb"
if (!file.exists(gdb_path)) {
  download.file(
    "https://www.arcgis.com/sharing/rest/content/items/c199f2799b724ffbacf4cafe3ee03e55/data",
    "~/Downloads/HPMS_2020.gdb.zip"
  )
  unzip("~/Downloads/HPMS_2020.gdb.zip", exdir = "~/Downloads")
}

hpms_states <-
  st_layers(dsn = gdb_path)$name |>
  strsplit("_", fixed = TRUE) |>
  purrr::map_chr(3)

extract_F12_AADT <- function(hpms_state = "OH") {
  hpms_state_d <-
    st_read(
      dsn = gdb_path,
      query = glue::glue(
        "SELECT AADT, AADT_SINGLE_UNIT, AADT_COMBINATION",
        "FROM HPMS_FULL_{hpms_state}_2020",
        "WHERE F_SYSTEM IN ('1', '2')",
        .sep = " "
      ),
      quiet = TRUE
    ) |>
    na.omit() |>
    st_zm() |>
    tibble::as_tibble() |>
    mutate(s2_geography = as_s2_geography(Shape), .keep = "unused")
  return(hpms_state_d)
}

all_states_aadt_f12 <-
  purrr::map(
    hpms_states,
    extract_F12_AADT,
    .progress = "extracting state F12 AADT files"
  )

aadt_f12 <- bind_rows(all_states_aadt_f12)

aadt_f12_sf <- st_as_sf(aadt_f12)

st_write(aadt_f12_sf, "./release_me/hpms_2020_f12_aadt.gpkg", driver = "GPKG")
