library(dplyr)
library(s2)
library(terra)

# for download.file:
options(timeout = 300)

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
                          data_dir = fs::path_wd("data")) {
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
narr_fls <-
  tidyr::expand_grid(
    narr_year = as.character(2000:2022),
    narr_var = c("air.2m", "hpbl",
                 "acpcp", "rhum.2m",
                 "vis", "pres.sfc",
                 "uwnd.10m", "vwnd.10m")
  ) |>
  purrr::pmap_chr(download_narr)

# create raster stack of all NARR rasters
narr_var <- "air.2m"
narr_stack <- rast(grep(narr_var, narr_fls, value = TRUE, fixed = TRUE))

narr_stack[5]


## names(narr_stack) <- as.Date(time(narr_stack))

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  mutate(lon = as.matrix(s2_cell_to_lnglat(s2))[,"x"],
         lat = as.matrix(s2_cell_to_lnglat(s2))[,"y"])

lyrs <- base::match(d$data[[1]]$date, as.Date(time(narr_stack)))

terra::extract(narr_stack, vect(d[1, c("lon", "lat")]), layer = "air_1")
  
## d_sf <-
##   d |>
##   mutate(s2_geometry = as_s2_geography(s2_cell_to_lnglat(s2))) |>
##   sf::st_as_sf() |>
##   sf::st_transform(terra::crs(narr_stack))

cells(narr_stack, vect(d[5, c("lon", "lat")]))

d$narr_cell <- cells(narr_stack, vect(d[ , c("lon", "lat")]))[ , "cell"]

extract(narr_stack, d$narr_cell[5])

d$narr_cell[[5]]
d$data[[5]]$date

hmm <- terra::extract(narr_stack, d[5, c("lon", "lat")], layers = d$data[[5]]$date, ID = FALSE)

str(hmm, 1)

length(d$data[[1]]$date)


d_narr <-
  purrr::map(1:3,
           \(.) {
             terra::extract(narr_stack, d[., c("lon", "lat")], layers = d$data[[.]]$date, ID = FALSE) |>
               unlist() |>
               setNames(NULL)
           },
           .progress = "joining NARR data")

purrr::map2(d_narr, d$data[1:3], \(x, y) mutate(y, air.2m = x))

d_narr[[1]]
d$data[1:3][[1]]


unlist(d_narr[[1]])

terra::extract(narr_stack, d[1, c("lon", "lat")], layers = d$data[[1]]$date, ID = FALSE) |>
  as.vector()

# create lookup table of all dates for values linked to input points
d_narr <-
  extract(narr_stack, d_vect, ID = FALSE) |>
  tibble::as_tibble() |>
  mutate(s2 = d_vect$s2) |>
  tidyr::pivot_longer(-s2, names_to = "date", values_to = narr_var) |>
  mutate(date = as.Date(date))

# join back into data
d$data <-
  purrr::map2(
    d$data,
    d$s2,
    \(x, y) left_join(x, filter(d_narr, s2 == as.character(y)), by = "date"),
    .progress = "joining NARR data"
  )

d

d$data[[100]]
