% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/nlcd_frac_imperv.R
\name{get_nlcd_frac_imperv}
\alias{get_nlcd_frac_imperv}
\alias{install_nlcd_frac_imperv_data}
\title{Get NLCD Fractional Impervious Surface}
\usage{
get_nlcd_frac_imperv(x, dates, fun = stats::median, buffer = 400)

install_nlcd_frac_imperv_data(nlcd_year = as.character(2025:2017))
}
\arguments{
\item{x}{a vector of s2 cell identifers (\code{s2_cell} object)}

\item{dates}{a list of date vectors for the NLCD data, must be the same length as \code{x}}

\item{fun}{function to summarize extracted data}

\item{buffer}{distance from s2 cell (in meters) to summarize data}

\item{nlcd_year}{a character string that is the year for the NLCD data}
}
\value{
for \code{get_nlcd_frac_imperv()}, a list of numeric vectors of fractional impervious
surface pixel summaries, the same length as \code{x};
each vector has values for each date in dates, named according to the NLCD product year

for \code{install_nlcd_frac_imperv_data()}, a character string path to NLCD raster data
}
\description{
NLCD data is from v1 of the \href{https://www.mrlc.gov/data/project/annual-nlcd}{Annual NLCD}
}
\examples{
d <- list(
  "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
  "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15"))
)
get_nlcd_frac_imperv(x = s2::as_s2_cell(names(d)), dates = d)
get_nlcd_frac_imperv(x = s2::as_s2_cell(names(d)), dates = d, fun = mean, buffer = 1000)
}
\references{
https://www.usgs.gov/centers/eros/science/annual-nlcd-fractional-impervious-surface
}
