FROM ghcr.io/rocker-org/r-ver:4.3.1

RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    libcurl4-openssl-dev \
    && apt-get clean

RUN R --quiet -e "install.packages('pak', repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

RUN R --quiet -e "pak::pak('geomarker-io/appc')"

# RUN R --quiet -e "install.packages('testthat', repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

# RUN R --quiet -e "install.packages('remotes', repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

# RUN R --quiet -e "remotes::install_github('geomarker-io/appc', INSTALL_opts = c('--with-keep.source', '--install-tests'), repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

# RUN R --quiet -e "testthat::test_package('appc')"
