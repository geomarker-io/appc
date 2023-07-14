library(dplyr)
library(grf)

d <-
  arrow::read_parquet("data/aqs.parquet") |>
  select(pollutant, dates, conc, s2)

# delete dups for now; fix in aqs script
duplicated <- 
  d |>
  select(pollutant, s2) |>
  duplicated() |>
  which()
d <- slice(d, -duplicated)


d <-
  left_join(d,
            select(arrow::read_parquet("data/narr.parquet"),
                   s2, pollutant, air.2m, hpbl, acpcp, rhum.2m, vis, pres.sfc, uwnd.10m, vwnd.10m),
            by = c("s2", "pollutant"))

d_nlcd <- arrow::read_parquet("data/nlcd.parquet")
