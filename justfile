# set shell := ["R", "-e"]
set dotenv-load
pkg_version := `Rscript -e "cat(desc::desc_get('Version'))"`

# document R package
document:
	R -e "devtools::document()"

# check R package
check:
	R -e "devtools::check()"

# build documentation website
build_site: document
	R -e "pkgdown::build_site(preview = TRUE)"

# make training data
make_training_data:
	Rscript inst/make_training_data.R

# upload training data to S3
upload_training_data:
	aws s3 cp inst/training_data.rds s3://geomarker-io/appc/training_data_{{pkg_version}}.rds --acl public-read

# train grf model
train:
    Rscript inst/train_model.R

