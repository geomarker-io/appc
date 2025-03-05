library(plumber)
r <- plumb("inst/plumber.R")  # Load the API definition
r$run(port = 8000)       # Run the API on port 8000