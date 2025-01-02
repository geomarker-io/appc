# set shell := ["R", "-e"]
set dotenv-load
pkg_version := `Rscript -e "cat(desc::desc_get('Version'))"`
geomarker_folder := `Rscript -e "cat(tools::R_user_dir('appc', 'data'))"`

# make training data for GRF
make_training_data:
  Rscript --verbose inst/make_training_data.R

# train grf model and render report
train_model:
  Rscript --verbose inst/train_model.R
  R -e "rmarkdown::render('./vignettes/articles/cv-model-performance.Rmd', knit_root_dir = getwd())"
  open vignettes/articles/cv-model-performance.html

# upload grf model and training data to current github release
release_model:
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/training_data_v{{pkg_version}}.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/rf_pm_v{{pkg_version}}.qs"
