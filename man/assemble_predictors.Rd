% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/assemble.R
\name{assemble_predictors}
\alias{assemble_predictors}
\title{Assemble a tibble of required predictors for the exposure assessment model}
\usage{
assemble_predictors(x, dates, pollutant = c("pm25"))
}
\arguments{
\item{x}{a vector of s2 cell identifers (\code{s2_cell} object); currently required to be within the contiguous united states}

\item{dates}{a list of date vectors for the predictions, must be the same length as \code{x}}

\item{pollutant}{ignored now, but reserved for future sets of predictors specific to different pollutants}
}
\value{
a tibble with one row for each unique s2 location - date combination where columns
are predictors required for the exposure assessment model
}
\description{
Assemble a tibble of required predictors for the exposure assessment model
}
\examples{
d <- list(
  "8841b39a7c46e25f" = as.Date(c("2023-05-18", "2023-11-06")),
  "8841a45555555555" = as.Date(c("2023-06-22", "2023-08-15", "2023-09-30"))
)
assemble_predictors(x = s2::as_s2_cell(names(d)), dates = d) |>
  tibble::glimpse()
}
