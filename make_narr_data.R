library(dplyr)
library(s2)
library(terra)
library(purrr)
options(timeout = 300)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  mutate(
    lon = as.matrix(s2_cell_to_lnglat(s2))[, "x"],
    lat = as.matrix(s2_cell_to_lnglat(s2))[, "y"]
  )

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

## # optional: pre-download all NARR files ahead of time
## # this is not required and the code below it will download
## # NARR files as needed (per year-variable combination)
## narr_fls <-
##   tidyr::expand_grid(
##     narr_year = as.character(2000:2022),
##     narr_var = c(
##       "air.2m", "hpbl",
##       "acpcp", "rhum.2m",
##       "vis", "pres.sfc",
##       "uwnd.10m", "vwnd.10m"
##     )
##   ) |>
##   purrr::pmap_chr(download_narr)

narr_vars <- c(
  "air.2m", "hpbl",
  "acpcp", "rhum.2m",
  "vis", "pres.sfc",
  "uwnd.10m", "vwnd.10m"
)

for (nv in narr_vars) {
  narr_stack <-
    tidyr::expand_grid(
      narr_year = as.character(2000:2022),
      narr_var = nv,
    ) |>
    pmap_chr(download_narr) |>
    rast()
  names(narr_stack) <- as.Date(time(narr_stack))

  d$narr_cell <-
    terra::cells(
      narr_stack,
      project(
        vect(select(d, lat, lon), crs = "epsg:4326"),
        narr_stack
      )
    )[, "cell"]

  d[[nv]] <-
    map(1:nrow(d),
      \(x) {
        narr_stack[d$narr_cell[[x]], k = as.character(d$dates[[x]])] |>
          unlist()
      },
      .progress = nv
    )

  d$narr_cell <- NULL
  message("✓ ", nv)
}

dir.create("data", showWarnings = FALSE)
arrow::write_parquet(d, "data/narr.parquet")
