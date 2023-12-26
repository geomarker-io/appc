data/aqs.rds: R/aqs.R
	Rscript R/aqs.R

data/elevation.rds: data/aqs.rds R/elevation.R
	Rscript R/elevation.R

data/tract.rds: data/aqs.rds R/tract.R
	Rscript R/tract.R

data/smoke.rds: data/tract.rds R/smoke.R
	Rscript R/smoke.R

data/narr.rds: data/aqs.rds R/narr.R
	Rscript R/narr.R

data/nlcd.rds: data/aqs.rds R/nlcd.R
	Rscript R/nlcd.R

data/nei.rds: data/aqs.rds R/nei.R
	Rscript R/nei.R

data/traffic.rds: data/aqs.rds R/traffic.R
	Rscript R/traffic.R

data/train.rds: data/aqs.rds data/elevation.rds data/narr.rds data/nlcd.rds data/nei.rds data/traffic.rds R/make_model_train_data.R
	Rscript R/make_model_train_data.R
