#' Convert latitude/longitude vectors into S2 cells
#'
#' @param lat Numeric vector of latitudes (decimal degrees)
#' @param lon Numeric vector of longitudes (decimal degrees)
#' @return An object of class `s2_cell`
#' @export
#' @examples
#' latlon_to_s2_cell(
#'   lat = c(45.0, 46.1),
#'   lon = c(-64.2, -65.3)
#' )
latlon_to_s2_cell <- function(lat, lon) {
  stopifnot(is.numeric(lat), is.numeric(lon))
  if (length(lat) != length(lon)) {
    stop("`lat` and `lon` must have the same length.")
  }
  ll <- s2::s2_lnglat(lon, lat)
  cells <- s2::as_s2_cell(ll)
  return(cells)
}
