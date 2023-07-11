library(dplyr)
library(s2)
library(terra)
library(purrr)

options(timeout = 300)
download_dir <- fs::path_wd("narr_downloads")
dir.create(download_dir, showWarnings = FALSE)

d <- arrow::read_parquet("data/aqs.parquet")

# download NARR raster
# https://psl.noaa.gov/data/gridded/data.narr.html
download_narr <- function(narr_var, narr_year) {
  narr_file_path <- fs::path(download_dir,
                             glue::glue("narr_{narr_var}_{narr_year}.nc"))
  if (file.exists(narr_file_path)) {
    return(narr_file_path)
  }
  message(glue::glue("downloading {narr_year} {narr_var}..."))
  glue::glue("https://downloads.psl.noaa.gov",
             "Datasets", "NARR", "Dailies", "monolevel",
             "{narr_var}.{narr_year}.nc",
             .sep = "/"
             ) |>
    download.file(destfile = narr_file_path)
  return(narr_file_path)
}

narr_vars <- c(
  "air.2m", "hpbl",
  "acpcp", "rhum.2m",
  "vis", "pres.sfc",
  "uwnd.10m", "vwnd.10m"
)

narr_years <- 2000:2022

# create NARR subdataset, using download_dir, set above
# if already downloaded, files will be reused instead of redownloaded
narr_sds <-
  map(narr_vars, \(x) {
    tidyr::expand_grid(
      narr_var = x,
      narr_year = as.character(narr_years),
      ) |>
      pmap_chr(download_narr) |>
      rast()
  }) |>
  sds()
names(narr_sds) <- narr_vars

d_vect <-
  d |>
  mutate(
    lat = as.matrix(s2_cell_to_lnglat(s2))[, "y"],
    lon = as.matrix(s2_cell_to_lnglat(s2))[, "x"]
  ) |>
  vect(crs = "epsg:4326") |>
  project(narr_sds)

d$narr_cell <- terra::cells(narr_sds[["air.2m"]], d_vect)[ , "cell"]

for (nv in names(narr_sds)) {
  message("extracting ", nv," ...")
  narr_rstr <- narr_sds[[nv]]
  names(narr_rstr) <- as.Date(time(narr_rstr))
  xx <- terra::extract(narr_rstr, d$narr_cell)
  d[[nv]] <-
    imap(d$dates,
         \(x, idx) unlist(xx[idx, as.character(x)]),
         .progress = "extracting dates")
  message("        ... ✓ complete")
}

arrow::write_parquet(d, "data/narr.parquet")
