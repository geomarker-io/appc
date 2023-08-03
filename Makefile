all: model/rf_pm.rds

data/aqs.parquet:
	Rscript make_aqs_data.R

data/elevation.parquet: data/aqs.parquet
	Rscript make_elevation_data.R

data/narr.parquet: data/aqs.parquet
	Rscript make_narr_data.R

data/nlcd.parquet: data/aqs.parquet
	Rscript make_nlcd_data.R

data/tract.parquet: data/aqs.parquet make_tract_id.R
	Rscript make_tract_id.R
data/train.parquet: data/aqs.parquet data/elevation.parquet data/narr.parquet data/nlcd.parquet
	Rscript make_model_train_data.R

model/rf_pm.rds: data/train.parquet
	Rscript make_model.R
