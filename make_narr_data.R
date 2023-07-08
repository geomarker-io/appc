library(dplyr)
library(s2)
library(terra)
library(purrr)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  mutate(
    lon = as.matrix(s2_cell_to_lnglat(s2))[, "x"],
    lat = as.matrix(s2_cell_to_lnglat(s2))[, "y"]
  )

# TODO
d <- slice_sample(d, n = 5)

# TODO make this structure from beginning in make_aqs_data.R
# make data column into named dbl called pollutant
d <-
  d |>
  mutate(conc = map(data, tibble::deframe)) |>
  select(-data)

#' download NARR raster
#'
# https://psl.noaa.gov/data/gridded/data.narr.html
#' @param narr_var  the name of a NARR variable
#' @param narr_year the calendar year of the NARR data
#' @param data_dir the directory where the NARR raster will be saved
#' @return the file location of the downloaded NARR raster
download_narr <- function(narr_var = c(
                            "air.2m", "hpbl",
                            "acpcp", "rhum.2m",
                            "vis", "pres.sfc",
                            "uwnd.10m", "vwnd.10m"
                          ),
                          narr_year = as.character(2000:2023),
                          data_dir = fs::path_wd("narr_downloads")) {
  narr_var <- rlang::arg_match(narr_var, multiple = FALSE)
  narr_year <- rlang::arg_match(narr_year)
  narr_file_path <- fs::path(
    data_dir,
    glue::glue("narr_{narr_var}_{narr_year}.nc")
  )
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

# download all NARR files
options(timeout = 300)
narr_fls <-
  tidyr::expand_grid(
    narr_year = as.character(2000:2022),
    narr_var = c(
      "air.2m", "hpbl",
      "acpcp", "rhum.2m",
      "vis", "pres.sfc",
      "uwnd.10m", "vwnd.10m"
    )
  ) |>
  purrr::pmap_chr(download_narr)

# create raster stack of all NARR rasters
narr_var <- "air.2m"
narr_stack <- rast(grep(narr_var, narr_fls, value = TRUE, fixed = TRUE))
names(narr_stack) <- as.Date(time(narr_stack))

d$narr_cell <-
  terra::cells(
    narr_stack,
    project(
      vect(select(d, lat, lon), crs = "epsg:4326"),
      narr_stack
    )
  )[ , "cell"]

# NEXT how to use cells to extract vectors of values based on dates
# dates == names(conc)

