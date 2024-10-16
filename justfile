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
  R -e "rmarkdown::render('./vignettes/cv-model-performance.Rmd', knit_root_dir = getwd())"
  open vignettes/cv-model-performance.html

# upload grf model and training data to current github release
release_model:
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/training_data_v{{pkg_version}}.rds"
  gh release upload v{{pkg_version}} "{{geomarker_folder}}/rf_pm_v{{pkg_version}}.qs"

# upload merra data to github release
release_merra_data:
  for year in {2017..2024}; do \
    rm -f "{{geomarker_folder}}"/merra_$year.rds; \
    APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_merra_data('$year')"; \
    gh release upload v{{pkg_version}} "{{geomarker_folder}}"/merra_$year.rds; \
  done

# # install nlcd urban imperviousness data from source and upload to github release
# release_urban_imperviousness_data:
#   for year in 2016 2019 2021; do \
#     rm -f "{{geomarker_folder}}"/urban_imperviousness_$year.tif; \
#     APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_impervious('$year')"; \
#     gh release upload v{{pkg_version}} "{{geomarker_folder}}"/urban_imperviousness_$year.tif; \
#   done

# # install nei data from source and upload to github release
# release_nei_data:
#   for year in 2017 2020; do \
#     rm -f "{{geomarker_folder}}"/nei_$year.rds; \
#     APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_nei_point_data('$year')"; \
#     gh release upload v{{pkg_version}} "{{geomarker_folder}}"/nei_$year.rds; \
#   done

# # install traffic data from source and upload to github release
# release_traffic_data:
#   rm -f "{{geomarker_folder}}/hpms_f123_aadt.rds"
#   APPC_INSTALL_DATA_FROM_SOURCE=1 Rscript -e "if (file.exists('./inst')) devtools::load_all" -e "appc::install_traffic()"
#   gh release upload v{{pkg_version}} "{{geomarker_folder}}/hpms_f123_aadt.rds"


