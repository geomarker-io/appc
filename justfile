# set shell := ["R", "-e"]
set dotenv-load
pkg_version := `Rscript -e "cat(desc::desc_get('Version'))"`
geomarker_folder := `Rscript -e "cat(tools::R_user_dir('appc', 'data'))"`

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
  install_smoke_pm_data()
  purrr::map_chr(as.character(2017:2023), install_merra_data)
  
# run tests without cached release files
docker_test:
  docker build -t appc-test Dockerfile.testing

# build docker image preloaded with {appc} and data
docker_tool:
  docker build -t appc Dockerfile.tool

# data > train > report
model_refresh: dl_geomarker_data make_training_data train report

# make training data
make_training_data:
  Rscript --verbose inst/make_training_data.R

# train grf model
train:
  Rscript --verbose inst/train_model.R

# upload grf model to current github release
release_grf:
  cp rf_pm.rds "{{geomarker_folder}}"/rf_pm.rds
  gh release upload v{{pkg_version}} "rf_pm.rds"

# create CV accuracy report
report:
  R -e "rmarkdown::render('./inst/APPC_prediction_evaluation.Rmd', knit_root_dir = getwd())"
  open inst/APPC_prediction_evaluation.html

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
  APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "install_smoke_pm_data()"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/smoke.rds"

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

