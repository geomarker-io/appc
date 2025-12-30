# set shell := ["R", "-e"]

set dotenv-load := true

pkg_version := `Rscript -e "cat(desc::desc_get('Version'))"`
pkg_version_major := "1"
geomarker_folder := `Rscript -e "cat(tools::R_user_dir('appc', 'data'))"`

# make training data for GRF
make_training_data:
    Rscript --verbose inst/make_training_data.R

# train grf model
train_model:
    Rscript --verbose inst/train_model.R

# render model performance dashboard
render_model_dash:
    R -e "rmarkdown::render('./vignettes/articles/cv-model-performance.Rmd', knit_root_dir = getwd())"
    open vignettes/articles/cv-model-performance.html

# draft release rf_pm model file on github under the major version
draft_release_model:
    gh release create rf_pm_v{{ pkg_version_major }} \
    --title "{appc} random forest PM2.5 prediction model, v{{ pkg_version_major }}" \
    --notes "This .rds file contains a {grf} object designed to be used with the {appc} package (major version: v{{ pkg_version_major }})." \
    --draft \
    "{{ geomarker_folder }}/rf_pm_v{{ pkg_version_major }}.qs" \
    "{{ geomarker_folder }}/training_data_v{{ pkg_version_major }}.rds" && \
    echo "\n\n✅ Now publish the draft release after adding date coverage details and unchecking 'Set as the latest release' on github.com\n\n"
