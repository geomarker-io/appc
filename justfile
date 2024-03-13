# set shell := ["R", "-e"]
set dotenv-load
pkg_version := `Rscript -e "cat(desc::desc_get('Version'))"`
geomarker_folder := `Rscript -e "cat(tools::R_user_dir('appc', 'data'))"`

# CRAN check package
check:
  #!/usr/bin/env Rscript
  devtools::document()
  devtools::check()

# build readme and webpage
build_site:
  #!/usr/bin/env Rscript
  devtools::document()
  pkgdown::build_site()

# download all geomarker ahead of time, if not already cached
dl_geomarker_data:
  #!/usr/bin/env Rscript
  library(appc)
  install_elevation_data()
  install_traffic()
  tidyr::expand_grid(narr_var = c("air.2m", "hpbl", "acpcp", "rhum.2m", "vis", "pres.sfc", "uwnd.10m", "vwnd.10m"),
                     narr_year = as.character(2017:2023)) |>
    purrr::pmap_chr(install_narr_data)
  purrr::map_chr(c("2017", "2020"), install_nei_point_data)
  purrr::map_chr(c("2016", "2019", "2021"), install_urban_imperviousness)
  install_hms_smoke_data()
  purrr::map_chr(as.character(2017:2023), install_merra_data)
  
# run tests without cached release files
docker_test:
  docker build -t appc-test -f Dockerfile.testing .

# build docker image preloaded with {appc} and data
docker_tool:
  docker build -t appc -f Dockerfile.tool .

# make training data for GRF
make_training_data:
  Rscript --verbose inst/make_training_data.R

# train grf model and render report
train_model:
  Rscript --verbose inst/train_model.R
  R -e "rmarkdown::render('./vignettes/cv-model-performance.Rmd', knit_root_dir = getwd())"
  open vignettes/cv-model-performance.html

# upload grf model and training data to current github release
release_model:
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/training_data_v{{pkg_version}}.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/rf_pm_v{{pkg_version}}.rds"

# install nlcd urban imperviousness data from source and upload to github release
release_urban_imperviousness_data:
  for year in 2016 2019 2021; do \
    rm -f "{{geomarker_folder}}"/urban_imperviousness_$year.tif; \
    APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_impervious('$year')"; \
    gh release upload v{{pkg_version}} "{{geomarker_folder}}"/urban_imperviousness_$year.tif; \
  done

# install nei data from source and upload to github release
release_nei_data:
  for year in 2017 2020; do \
    rm -f "{{geomarker_folder}}"/nei_$year.rds; \
    APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_nei_point_data('$year')"; \
    gh release upload v{{pkg_version}} "{{geomarker_folder}}"/nei_$year.rds; \
  done

# install smoke data from source and upload to github release
release_smoke_data:
  rm -f "{{geomarker_folder}}/smoke.rds"
  APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_smoke_pm_data()"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/smoke.rds"

# install smoke data from source and upload to github release
release_hms_smoke_data:
  rm -f "{{geomarker_folder}}/hms_smoke.rds"
  APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_hms_smoke_data()"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/hms_smoke.rds"

# install traffic data from source and upload to github release
release_traffic_data:
  rm -f "{{geomarker_folder}}/hpms_f123_aadt.rds"
  APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_traffic()"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/hpms_f123_aadt.rds"

# upload merra data to github release
release_merra_data:
  for year in {2017..2023}; do \
    rm -f "{{geomarker_folder}}"/merra_$year.rds; \
    APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_merra_data('$year')"; \
    gh release upload v{{pkg_version}} "{{geomarker_folder}}"/merra_$year.rds; \
  done

