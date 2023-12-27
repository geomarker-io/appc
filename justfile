# set shell := ["R", "-e"]

# train grf model
model:
    Rscript model/make_model.R

# make training data
train:
    make data/train.rds

install:
    R -e "if (!require(pak)) install.packages('pak')"
    R -e "pak::pak()"
