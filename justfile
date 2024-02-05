# set shell := ["R", "-e"]
set dotenv-load
pkg_version := `Rscript -e "cat(desc::desc_get('Version'))"`
geomarker_folder := `Rscript -e "cat(tools::R_user_dir('appc', 'data'))"`

# document R package
document:
  R -e "devtools::document()"

# check R package
check:
  R -e "devtools::check()"

# run tests without cached geomarker files
docker_test:
  docker build -t appc .

# build documentation website
build_site: document
  R -e "pkgdown::build_site(preview = TRUE, devel = TRUE)"

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
  rm -f "{{geomarker_folder}}/nei_2017.rds"
  R --quiet -e \
    "devtools::load_all(); \
     options('appc_install_data_from_source' = TRUE); \
     install_nei_point_data('2017')"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/nei_2017.rds"
  rm -f "{{geomarker_folder}}/nei_2020.rds"
  R --quiet -e \
    "devtools::load_all(); \
     options('appc_install_data_from_source' = TRUE); \
     install_nei_point_data('2020')"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/nei_2020.rds"

# install smoke data from source and upload to github release
release_smoke_data:
  rm -f "{{geomarker_folder}}/smoke.rds"
  R --quiet -e \
    "devtools::load_all(); \
     options('appc_install_data_from_source' = TRUE); \
     install_smoke_pm_data()"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/smoke.rds"

# install traffic data from source and upload to github release
release_traffic_data:
  rm -f "{{geomarker_folder}}/hpms_f123_aadt.rds"
  R --quiet -e \
    "devtools::load_all(); \
     options('appc_install_data_from_source' = TRUE); \
     options('timeout' = 3000); \
     install_traffic()"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/hpms_f123_aadt.rds"

# install merra data from source and upload to github release
release_merra_data:
  export APPC_INSTALL_DATA_FROM_SOURCE=TRUE
  rm "{{geomarker_folder}}/merra_2017.rds"
  R -f -e "install_merra_data('2017')"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2017.rds"
  rm "{{geomarker_folder}}/merra_2018.rds"
  R -f -e "install_merra_data('2018')"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2018.rds"
  rm "{{geomarker_folder}}/merra_2017.rds"
  R -f -e "install_merra_data('2017')"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2017.rds"

