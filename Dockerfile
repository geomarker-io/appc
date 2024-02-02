FROM ghcr.io/rocker-org/r-ver:4.3.1

RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    libcurl4-openssl-dev \
    && apt-get clean

RUN R --quiet -e "install.packages('pak', repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

RUN R --quiet -e "pak::pak('geomarker-io/appc')"
