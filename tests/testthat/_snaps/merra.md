# get_merra_data works

    Code
      get_merra_data(x = s2::as_s2_cell(names(d)), dates = d)
    Output
      $`8841b39a7c46e25f`
      # A tibble: 2 x 6
        merra_dust merra_oc merra_bc merra_ss merra_so4 merra_pm25
             <dbl>    <dbl>    <dbl>    <dbl>     <dbl>      <dbl>
      1      1.77      6.84    0.532    0.994      2.43      13.5 
      2      0.842     2.65    0.392    0.244      2.21       7.17
      
      $`8841a45555555555`
      # A tibble: 2 x 6
        merra_dust merra_oc merra_bc merra_ss merra_so4 merra_pm25
             <dbl>    <dbl>    <dbl>    <dbl>     <dbl>      <dbl>
      1       1.34     2.52    0.327    0.356      3.71       9.64
      2       1.18     2.80    0.441    0.722      5.78      13.1 
      

