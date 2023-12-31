# set shell := ["R", "-e"]

# document R package
document:
	R -e "devtools::document()"

# check R package
check:
	R -e "devtools::check()"

# install required R packages
install:
    R -e "if (!require(pak)) install.packages('pak')"
    R -e "pak::pak()"

# make training data
data:
	Rscript inst/make_training_data.R

# train grf model
train:
    Rscript inst/train_model.R

