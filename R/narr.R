#' installs NARR raster data into user's data directory for the `appc` package
#' @param narr_var a character string that is the name of a NARR variable
#' @param narr_year a character string that is the year for the NARR data
#' @references https://psl.noaa.gov/data/gridded/data.narr.html
install_narr_data <- function(narr_var = c("air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m"),
                              narr_year = as.character(2016:2022)) {
  narr_var <- rlang::arg_match(narr_var)
  narr_year <- rlang::arg_match(narr_year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("narr_{narr_var}_{narr_year}.nc"))
  if (file.exists(dest_file)) return(dest_file)
  message(glue::glue("downloading {narr_year} {narr_var}..."))
  glue::glue("https://downloads.psl.noaa.gov",
             "Datasets", "NARR", "Dailies", "monolevel",
             "{narr_var}.{narr_year}.nc",
             .sep = "/"
             ) |>
    download.file(destfile = dest_file)
  return(dest_file)
}

#' get narr data for a spatiotemporal location
#' @param x a vector of s2 cell identifers (`s2_cell` object)
#' @param dates a vector of dates that are dates of the NARR data, must be the same length as `x`
#' @param narr_var a character string that is the name of a NARR variable
#' @references https://psl.noaa.gov/data/gridded/data.narr.html
#' @return a numeric vector of NARR values for each s2 location and date combination
get_narr_data <- function(x, narr_var = "air.2m", dates = as.Date("2022-03-22")) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  narr_raster <-
    dates |>
    format("%Y") |>
    unique() |>
    purrr::map_chr(\(.) install_narr_data(narr_var = narr_var, narr_year = .)) |>
    purrr::map(terra::rast) |>
    terra::sds()
  ## names(narr_raster) <- as.Date(terra::time(narr_raster))
  x_vect <-
    s2::s2_cell_to_lnglat(x) |>
    as.data.frame() |>
    terra::vect(geom = c("x", "y"), crs = "+proj=longlat +datum=WGS84") |>
    terra::project(narr_raster)

  narr_cells <- terra::cells(narr_raster[[1]], x_vect)[, "cell"]

  out <-
    tibble::tibble(
    s2 = x,
    date = dates,
    narr_cell = narr_cells
    )

  terra::extract(narr_raster[[1]], out$narr_cell)

  
  terra::extract(narr_raster, x_vect, layer = dates)$value
}

library(dplyr, warn.conflicts = FALSE)
## library(purrr)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  tidyr::unnest(cols = c("dates", "conc")) |>
  rename(date = dates) |>
  distinct(s2, date)

d$air.2m <- get_narr_data(x = d$s2, dates = d$date, narr_var = "air.2m")

air.2m <-
  get_narr_data(d$s2, narr_var = "air.2m", dates = d$date) |>
  tidyr::pivot_longer(-s2, names_to = "date", values_to = "air.2m") |>

left_join(d, air.2m, by = c("s2", "date"))

d$air.2m <-
  purrr::map2_dbl(d$s2,
                  d$date,
                  \(xx, yy) get_narr_data(x = s2::as_s2_cell(xx), narr_var = "air.2m", date = yy))

narr_vars <- c(
  "air.2m", "hpbl",
  "acpcp", "rhum.2m",
  "vis", "pres.sfc",
  "uwnd.10m", "vwnd.10m"
)

narr_years <- 2016:2022

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

d$narr_cell <- terra::cells(narr_sds[["air.2m"]], d_vect)[, "cell"]

for (nv in names(narr_sds)) {
  message("extracting ", nv, " ...")
  narr_rstr <- narr_sds[[nv]]
  names(narr_rstr) <- as.Date(time(narr_rstr))
  xx <- terra::extract(narr_rstr, d$narr_cell)
  d[[nv]] <-
    imap(d$dates,
      \(x, idx) unlist(xx[idx, as.character(x)]),
      .progress = "extracting dates"
    )
  message("        ... ✓ complete")
}

arrow::write_parquet(d, "data/narr.parquet")
