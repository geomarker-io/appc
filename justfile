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

# build wasm binary
build_wasm_binary: create_wasm_repo
  docker run -it --rm \
  -v ${PWD}:/the_package \
  -w /the_package \
  ghcr.io/r-wasm/webr:main \
  R --silent \
  -e "install.packages('pak')" \
  -e "pak::pak('r-wasm/rwasm')" \
  -e "library(rwasm)" \
  -e "add_pkg('addr=local::.', repo_dir = './repo', dependencies = FALSE)"

# create wasm repo folders
create_wasm_repo:
	rm -rf ./repo
	mkdir -p ./repo/src/contrib
	mkdir -p ./repo/bin/emscripten/contrib/4.4
	chmod -R 777 ./repo/

# serve local test package repo
serve_test_repo:
  echo "go to https://webr.r-wasm.org/latest/ and run" && \
  echo "webr::install('appc', repos = c('http://127.0.0.1:9090', 'https://cloud.r-project.org'))" && \
  R --silent -e "httpuv::runStaticServer(dir = '.', port = 9090, browse = FALSE, headers = list('Access-Control-Allow-Origin' =  '*'))"
