#BSUB -W 30:00
#BSUB -n 2
#BSUB -M 24000
#BSUB -R "span[ptile=2]"
#BSUB -e install_merra.out
#BSUB -o install_merra.out

module load singularity
export APPC_INSTALL_DATA_FROM_SOURCE=1

for year in "2022" "2021" "2020" "2019" "2018" "2017";
do
    rm -f ~/.local/share/R/appc/merra_$year.rds
    singularity exec ~/singr_latest.sif \
        Rscript \
        -e "dotenv::load_dot_env()" \
        -e "httr::set_config(httr::use_proxy('http://bmiproxyp.chmcres.cchmc.org', 80, Sys.getenv('CCHMC_USERNAME'), Sys.getenv('CCHMC_PASSWORD')))" \
        -e "appc::install_merra_data('$year')"
done
