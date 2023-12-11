all: data train
data: data/train.parquet
train: model/rf_pm.rds

data/aqs.parquet: R/make_aqs_data.R
	Rscript R/make_aqs_data.R

data/elevation.parquet: data/aqs.parquet R/make_elevation_data.R
	Rscript R/make_elevation_data.R

data/narr.parquet: data/aqs.parquet R/make_narr_data.R
	Rscript R/make_narr_data.R

data/nlcd.parquet: data/aqs.parquet R/make_nlcd_data.R
	Rscript R/make_nlcd_data.R

data/tract.parquet: data/aqs.parquet R/make_tract_id.R
	Rscript R/make_tract_id.R

data/smoke.parquet: data/tract.parquet R/make_smoke_data.R
	Rscript R/make_smoke_data.R

data/nei.parquet: data/aqs.parquet R/make_nei_data.R
	Rscript R/make_nei_data.R

data/traffic.parquet: data/aqs.parquet R/make_traffic_data.R
	Rscript R/make_traffic_data.R

data/train.parquet: data/aqs.parquet data/elevation.parquet data/narr.parquet data/nlcd.parquet data/nei.parquet data/traffic.parquet R/make_model_train_data.R
	Rscript R/make_model_train_data.R

model/rf_pm.rds: data/train.parquet R/make_model.R
	Rscript R/make_model.R
