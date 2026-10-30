# Convert latitude/longitude vectors into S2 cells

Convert latitude/longitude vectors into S2 cells

## Usage

``` r
latlon_to_s2_cell(lat, lon)
```

## Arguments

- lat:

  Numeric vector of latitudes (decimal degrees)

- lon:

  Numeric vector of longitudes (decimal degrees)

## Value

An object of class `s2_cell`

## Examples

``` r
latlon_to_s2_cell(
  lat = c(45.0, 46.1),
  lon = c(-64.2, -65.3)
)
```
