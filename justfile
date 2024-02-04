# set shell := ["R", "-e"]
set dotenv-load
pkg_version := `Rscript -e "cat(desc::desc_get('Version'))"`

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

# upload grf model to current github release
upload_grf:
  gh release upload v{{pkg_version}} "inst/rf_pm.rds"

geomarker_folder := `Rscript -e "cat(tools::R_user_dir('appc', 'data'))"`
# upload precomputed geomarker data to current github release
upload_geo_data:
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/smoke.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/hpms_f123_aadt.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/nei_2020.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/nei_2017.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2017.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2018.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2019.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2020.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2021.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2022.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/merra_2023.rds"

# train grf model
train:
  Rscript inst/train_model.R

# create CV accuracy report
report:
  R -e "rmarkdown::render('./inst/APPC_prediction_evaluation.Rmd')"
  open inst/APPC_prediction_evaluation.html
