# set shell := ["R", "-e"]

# train grf model
model:
    Rscript model/make_model.R

# make training data
data:
    make data/train.rds

# install required R packages
install:
    R -e "if (!require(pak)) install.packages('pak')"
    R -e "pak::pak()"
