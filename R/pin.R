#' download and pin files
#' 
#' Files are downloaded to the R user data directory (i.e., `tools::R_user_dir("pin", "data")`)
#' so they can be cached across all of an R user's sessions and projects.
#' Specify an alternative download location by setting the `R_USER_DATA_DIR` environment variable (see `?tools::R_user_dir`). 
#' @param url URL of file to download
#' @param progress show messages about existing files and/or download progress bars?
#' @param overwrite overwrite existing downloaded file with same name?
#' @return a character string that is the file path to the downloaded file (invisibly)
#' @examples
#' \dontrun{
#' Sys.setenv("R_USER_DATA_DIR" = tempdir())
#' pin_file("https://geomarker.s3-us-east-2.amazonaws.com/nlcd_cog/nlcd_imperviousdesc_2019.tif")
#' }
pin_file <- function(url, overwrite = FALSE, progress = interactive()) {
  file_path <- httr2::url_parse(url)$path
  if (is.null(file_path)) {
    stop("The url provided (", url, ") must contain a path.", call. = FALSE)
  }
  dest_file <- fs::path_join(c(tools::R_user_dir("pin", "data"), file_path))
  dir.create(dirname(dest_file), showWarnings = FALSE, recursive = TRUE)
  if (file.exists(dest_file) & !overwrite) {
    if (progress) message("Using existing file at ", dest_file)
    return(invisible(dest_file))
  }
  # TODO get file size from header and interactively ask user if downloading a file of this size is OK
  the_req <- httr2::request(url)
  if (progress) the_req <- httr2::req_progress(the_req, type = "down")
  response <- httr2::req_perform(the_req, path = dest_file)
  message("saved to: ", dest_file)
  return(invisible(dest_file))
}
