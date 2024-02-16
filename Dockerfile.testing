FROM ghcr.io/rocker-org/r-ver:4.3.1

RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    libcurl4-openssl-dev \
    gdal-bin libgdal-dev libgeos-dev \
    libicu-dev libnetcdf-dev libproj-dev \
    libssl-dev libudunits2-dev \
    && apt-get clean

RUN R --quiet -e "install.packages('pak', repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

COPY DESCRIPTION ./DESCRIPTION

RUN R --quiet -e "pak::local_install_dev_deps()"

COPY ./ /appc/

RUN R CMD build appc

RUN R CMD INSTALL appc_*.tar.gz

RUN R CMD check --as-cran --no-manual --no-vignettes appc_*.tar.gz
