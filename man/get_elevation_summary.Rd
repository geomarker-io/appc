% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/elevation.R
\name{get_elevation_summary}
\alias{get_elevation_summary}
\alias{install_elevation_data}
\title{Get elevation summary data}
\usage{
get_elevation_summary(x, fun = stats::median, buffer = 800)

install_elevation_data()
}
\arguments{
\item{x}{a vector of s2 cell identifers (\code{s2_cell} object)}

\item{fun}{function to summarize extracted data}

\item{buffer}{distance from s2 cell (in meters) to summarize data}
}
\value{
for \code{get_elevation_summary()}, a numeric vector of elevation summaries, the same length as \code{x}

for \code{install_elevation_data()}, a character string path to elevation raster
}
\description{
The \code{fun} (e.g. \code{median()} or \code{sd()}) of the elevations (captured at a spatial resolution of 800 by 800 m) within
the buffer distance of each s2 geohash.
}
\examples{
get_elevation_summary(s2::as_s2_cell(c("8841b399ced97c47", "8841b38578834123")))
}
\references{
\url{https://prism.oregonstate.edu/normals/}
}
