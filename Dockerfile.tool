FROM ghcr.io/rocker-org/r-ver:4.3.1

RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    libcurl4-openssl-dev \
    gdal-bin libgdal-dev libgeos-dev \
    libicu-dev libnetcdf-dev libproj-dev \
    libssl-dev libudunits2-dev \
    && apt-get clean

RUN R --quiet -e "install.packages('pak', repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

RUN R --quiet -e "pak::pak('geomarker-io/appc')"

RUN R \
  -e "library(appc)" \
  -e "install_elevation_data()" \
  -e "install_traffic()" \
  -e "tidyr::expand_grid(narr_var = c('air.2m', 'hpbl', 'acpcp', 'rhum.2m', 'vis', 'pres.sfc', 'uwnd.10m', 'vwnd.10m'), narr_year = as.character(2017:2023)) |> purrr::pmap_chr(install_narr_data)" \
  -e "purrr::map_chr(c('2017', '2020'), install_nei_point_data)" \
  -e "purrr::map_chr(c('2016', '2019', '2021'), install_urban_imperviousness)" \
  -e "install_smoke_pm_data()" \
  -e "purrr::map_chr(as.character(2017:2023), install_merra_data)"

RUN R -e "example('predict_pm25', package = 'appc')"
