# set shell := ["R", "-e"]
set dotenv-load
pkg_version := `Rscript -e "cat(desc::desc_get('Version'))"`
geomarker_folder := `Rscript -e "cat(tools::R_user_dir('appc', 'data'))"`

# run tests without cached geomarker files
docker_test:
  docker build -t appc .

# make training data
make_training_data:
  Rscript inst/make_training_data.R

# train grf model
train:
  Rscript inst/train_model.R

# upload grf model to current github release
upload_grf:
  gh release upload v{{pkg_version}} "inst/rf_pm.rds"

# create CV accuracy report
report:
  R -e "rmarkdown::render('./inst/APPC_prediction_evaluation.Rmd')"
  open inst/APPC_prediction_evaluation.html

# install nei data from source and upload to github release
release_nei_data:
  for year in 2017 2020; do \
    rm -f "{{geomarker_folder}}"/nei_$year.rds; \
    APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "appc::install_nei_point_data('$year')"; \
    gh release upload v{{pkg_version}} "{{geomarker_folder}}"/nei_$year.rds; \
  done

# install smoke data from source and upload to github release
release_smoke_data:
  rm -f "{{geomarker_folder}}/smoke.rds"
  APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "install_smoke_pm_data()"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/smoke.rds"

# install traffic data from source and upload to github release
release_traffic_data:
  rm -f "{{geomarker_folder}}/hpms_f123_aadt.rds"
  APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "merra::install_traffic()"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/hpms_f123_aadt.rds"

# upload merra data to github release
release_merra_data:
  for year in {2017..2023}; do \
    rm -f "{{geomarker_folder}}"/merra_$year.rds; \
    APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "appc::install_merra_data('$year')"; \
    gh release upload v{{pkg_version}} "{{geomarker_folder}}"/merra_$year.rds; \
  done

