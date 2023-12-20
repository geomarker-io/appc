data/aqs.parquet: R/aqs.R
	Rscript R/aqs.R

data/elevation.parquet: data/aqs.parquet R/elevation.R
	Rscript R/elevation.R

data/tract.parquet: data/aqs.parquet R/tract.R
	Rscript R/tract.R

data/smoke.parquet: data/tract.parquet R/smoke.R
	Rscript R/smoke.R

data/narr.parquet: data/aqs.parquet R/narr.R
	Rscript R/narr.R

data/nlcd.parquet: data/aqs.parquet R/nlcd.R
	Rscript R/nlcd.R

data/nei.parquet: data/aqs.parquet R/nei.R
	Rscript R/nei.R

data/traffic.parquet: data/aqs.parquet R/traffic.R
	Rscript R/traffic.R

data/train.parquet: data/aqs.parquet data/elevation.parquet data/narr.parquet data/nlcd.parquet data/nei.parquet data/traffic.parquet R/make_model_train_data.R
	Rscript R/make_model_train_data.R
