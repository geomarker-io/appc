% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/aqs.R
\name{get_daily_aqs}
\alias{get_daily_aqs}
\title{Get daily AQS concentrations}
\usage{
get_daily_aqs(
  pollutant = c("pm25", "ozone", "no2"),
  year = as.character(2017:2024)
)
}
\arguments{
\item{pollutant}{one of "pm25", "ozone", or "no2"}

\item{year}{calendar year}
}
\value{
data.frame/tibble of pollutant concentrations with site id, lat/lon, and date
}
\description{
Pre-generated daily summary files are downloaded from the EPA AQS website
and filtered/harmonized as described in the Details.
}
\details{
For PM2.5 (FRM, non-FRM, and speciation), data is filtered to only observations with
a sample duration of "24 HOURS".
All pollutants measurements are removed if the observation percent
for the sampling period is less than 75.
When a pollutant is measured by more than one device on the same day at the same
s2 location, the average measurement is returned, ensuring unique measurements for each pollutant-location-day

Note: Historical measurements are subject to change and the EPA AQS website only stores
the latest versions.  Since this function always downloads the latest data from EPA AQS,
that means that it will could different results depending on the date it was run.
Similarly, the most recent year might not contain measurements for the entire calendar year.

Get all the files on the page and the date they were last updated:
\code{readr::read_csv("https://aqs.epa.gov/aqsweb/airdata/file_list.csv")}
}
\examples{
get_daily_aqs("pm25", "2024")
}
