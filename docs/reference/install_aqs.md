# Install daily PM2.5 averages

Daily data by state is downloaded from the AQS API and
filtered/harmonized as described in the details. Data from the EPA AQS
API are updated more frequently compared to the pre-generated daily
average files used by
[`get_daily_aqs()`](https://geomarker.io/appc/reference/get_daily_aqs.md).

## Usage

``` r
install_aqs(year = as.character(2026:2017), force_reinstall = FALSE)
```

## Arguments

- year:

  character; calendar year of data to install

- force_reinstall:

  logical; download data from original source instead of reusing older
  downloads

## Value

a character string path to an AQS data RDS file

## Details

Installing AQS data via the API requires a key associated with an email
address. Signup with the url putting in your email address; e.g.,
https://aqs.epa.gov/data/api/signup?email=my.email.address@emails.com
and look for an email with the key. Save these credentials as
environment variables (or in a `.env` file): `AQS_DATA_MART_API_EMAIL`
and `AQS_DATA_MART_API_KEY`

For PM2.5 (FRM, non-FRM, and speciation), data is filtered to only
observations with a sample duration of "24 HOURS". All pollutants
measurements are removed if the observation percent for the sampling
period is less than 75 or were indicated to be invalid. When a pollutant
is measured by more than one device on the same day at the same s2
location, the average measurement is returned, ensuring unique
measurements for each pollutant-location-day

## Examples

``` r
# Data Mart data can be more current than the bulk AQS daily files.
if (FALSE) { # \dontrun{
install_aqs("2026") |>
  readRDS()
} # }
```
