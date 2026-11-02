# set shell := ["R", "-e"]

set dotenv-load := true

model_version := `Rscript -e 'cat(read.dcf("inst/model-v3-spec.dcf")[1, "Model-Version"])'`
geomarker_version := `Rscript -e 'cat(read.dcf("inst/model-v3-spec.dcf")[1, "Geomarker-Version"])'`
coverage_start := `Rscript -e 'cat(read.dcf("inst/model-v3-spec.dcf")[1, "Coverage-Start"])'`
coverage_end := `Rscript -e 'cat(read.dcf("inst/model-v3-spec.dcf")[1, "Coverage-End"])'`
geomarker_folder := `Rscript -e "cat(tools::R_user_dir('appc', 'data'))"`

# make training data for GRF
make_training_data:
    Rscript --verbose inst/make_training_data.R

# train grf model
train_model:
    Rscript --verbose inst/train_model.R

# render model performance dashboard
render_model_dash:
    APPC_BUILD_MODEL_ARTICLES=true R -e "rmarkdown::render('./vignettes/articles/cv-model-performance.Rmd', knit_root_dir = getwd())"
    open vignettes/articles/cv-model-performance.html

# draft release rf_pm model file on github under the model generation
draft_release_model:
    gh release create rf_pm_v{{ model_version }} \
    --title "{appc} random forest PM2.5 prediction model, v{{ model_version }}" \
    --notes "Model generation {{ model_version }} uses geomarker {{ geomarker_version }}. Model and training data cover {{ coverage_start }} through {{ coverage_end }}." \
    --draft \
    "{{ geomarker_folder }}/rf_pm_v{{ model_version }}.rds" \
    "{{ geomarker_folder }}/training_data_v{{ model_version }}.rds" && \
    echo "\n\n✅ Now publish the draft release after adding date coverage details and unchecking 'Set as the latest release' on github.com\n\n"
