# set shell := ["R", "-e"]

# download and install geospatial source data
install_data:
	R -e "devtools::load_all(); install_geomarker_data()"

# document R package
document:
	R -e "devtools::document()"

# check R package
check:
	R -e "devtools::check()"

# make training data
data:
	Rscript inst/make_training_data.R

# train grf model
train:
    Rscript inst/train_model.R

