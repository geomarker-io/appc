## ges_disc_secrets <-
##   httr2::request("https://data.gesdisc.earthdata.nasa.gov/s3credentials") |>
##   httr2::req_auth_basic(username = earthdata_secrets["EARTHDATA_USERNAME"],
##                         password = earthdata_secrets["EARTHDATA_PASSWORD"]) |>
##   httr2::req_perform() |>
##   httr2::resp_body_string() |>
##   jsonlite::fromJSON()

## library(paws)

## s3 <- paws::s3(
##   config = list(
##     credentials = list(
##       creds = list(
##         access_key_id = ges_disc_secrets$accessKeyId,
##         secret_access_key = ges_disc_secrets$secretAccessKey,
##         session_token = ges_disc_secrets$sessionToken
##       )
##     )),
##   region = "us-west-2"
## )

## s3$list_buckets()

## s3_dl <- s3$get_object(
##   Bucket = "gesdisc-cumulus-prod-protected",
##   Key = "MERRA2/M2T1NXAER.5.12.4/2022/06/MERRA2_400.tavg1_2d_aer_Nx.20220610.nc4"
##   )
