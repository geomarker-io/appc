# download and convert v2021-4 NLCD tree canopy for CONUS to COG
# https://www.mrlc.gov/data/type/tree-canopy
install_nlcd_tree_canopy_cover <- function(year = as.character(2021:2017),
                                           install_dir = tools::R_user_dir("appc", "data")) {
  year <- rlang::arg_match(year)
  if (!fs::dir_exists(install_dir)) {
    stop("the directory ", install_dir, " does not exist", call. = FALSE)
  }
  dest_path <- fs::path(install_dir, glue::glue("nlcd_tcc_CONUS_{year}_v2021-4.tif"))
  if (fs::file_exists(dest_path)) {
    return(dest_path)
  }
  dl_url <- glue::glue("https://s3-us-west-2.amazonaws.com/mrlc/nlcd_tcc_CONUS_{year}_v2021-4.zip")
  dl_tmp <- tempfile(glue::glue("nlcd_tcc_CONUS_{year}_v2021-4"), fileext = ".zip")
  withr::local_options(timeout = 3000)
  download.file(dl_url, dl_tmp)
  unz_files <- unzip(dl_tmp, exdir = tempfile(glue::glue("nlcd_tcc_{year}")))
  unz_tiff_file <- grep(".tif$", unz_files, value = TRUE)
  system2("gdal_translate", c("-of COG", "-co BIGTIFF=YES", shQuote(unz_tiff_file), shQuote(dest_path)))
  return(dest_path)
}

## out_cogs <- vapply(as.character(2021:2017), install_nlcd_tree_canopy_cover, character(1))
