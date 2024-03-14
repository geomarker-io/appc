FROM ghcr.io/rocker-org/r-ver:4.3.1

RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    libcurl4-openssl-dev \
    gdal-bin libgdal-dev libgeos-dev \
    libicu-dev libnetcdf-dev libproj-dev \
    libssl-dev libudunits2-dev \
    && apt-get clean

RUN Rscript -e "install.packages('pak')"

RUN Rscript --quiet \
      # -e "options(repos = c(CRAN = 'https://p3m.dev/cran/__linux__/jammy/latest'))" \
      -e "pak::pak('geomarker-io/appc')"

RUN Rscript -e "library(appc)" -e "example(predict_pm25)"
