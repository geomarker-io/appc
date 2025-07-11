# the geography of the 2020 contiguous United States as a s2_geography object
contiguous_us <-
  tigris::states(year = 2020, progress_bar = FALSE) |>
  dplyr::filter(
    !NAME %in%
      c(
        "United States Virgin Islands",
        "Guam",
        "Commonwealth of the Northern Mariana Islands",
        "American Samoa",
        "Puerto Rico",
        "Alaska",
        "Hawaii"
      )
  ) |>
  sf::st_as_s2() |>
  s2::s2_union_agg() |>
  s2::s2_as_binary()

usethis::use_data(contiguous_us, internal = TRUE, overwrite = TRUE)
