#' installs NARR raster data into user's data directory for the `appc` package
#' @param narr_var a character string that is the name of a NARR variable
#' @param narr_year a character string that is the year for the NARR data
#' @return path to NARR raster data
#' @references https://psl.noaa.gov/data/gridded/data.narr.html
#' @export
install_narr_data <- function(narr_var = c("air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m"),
                              narr_year = as.character(2016:2022)) {
  narr_var <- rlang::arg_match(narr_var)
  narr_year <- rlang::arg_match(narr_year)
  dest_file <- fs::path(tools::R_user_dir("appc", "data"), glue::glue("narr_{narr_var}_{narr_year}.nc"))
  if (file.exists(dest_file)) return(dest_file)
  message(glue::glue("downloading {narr_year} {narr_var}:"))
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
#' @param dates a list of date vectors for the NARR data, must be the same length as `x`
#' @param narr_var a character string that is the name of a NARR variable
#' @references https://psl.noaa.gov/data/gridded/data.narr.html
#' @return a list of numeric vectors of NARR values (the same length as `x` and `dates`)
#' @export
get_narr_data <- function(x, dates, narr_var) {
  if (!inherits(x, "s2_cell")) stop("x must be a s2_cell vector", call. = FALSE)
  narr_raster <-
    dates |>
    unlist() |>
    as.Date() |>
    unique() |>
    format("%Y") |>
    unique() |>
    purrr::map_chr(\(.) install_narr_data(narr_var = narr_var, narr_year = .)) |>
    purrr::map(terra::rast) |>
    purrr::reduce(c)
  names(narr_raster) <- as.Date(terra::time(narr_raster))
  x_vect <-
    s2::s2_cell_to_lnglat(x) |>
    as.data.frame() |>
    terra::vect(geom = c("x", "y"), crs = "+proj=longlat +datum=WGS84") |>
    terra::project(narr_raster)
  narr_cells <- terra::cells(narr_raster[[1]], x_vect)[, "cell"]
  xx <- terra::extract(narr_raster, narr_cells)
  purrr::imap(d$dates,
    \(x, idx) unlist(xx[idx, as.character(x)]),
    .progress = paste0("calculating ", narr_var)
  )
}
