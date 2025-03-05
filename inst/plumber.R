library(plumber)
library(s2)
library(appc)

#* Predict PM2.5 levels
#* @param s2_cell s2 cell identifer (`s2_cell` object)
#* @param dates Comma-separated dates in YYYY-MM-DD format
#* @serializer json
#* @get /predict_pm25
function(s2_cell, dates) {
  # Convert s2 string to s2 cell object
  s2_cell <- s2::as_s2_cell(s2_cell)
  
  # Convert dates to a list of Date objects
  date_list <- strsplit(dates, ",")[[1]]
  date_list <- list(as.Date(date_list))

  if (is.null(date_list) || any(is.na(unlist(date_list)))) {
    return(list(error = "Invalid date format. Use YYYY-MM-DD."))
  }

  # Run prediction
  result <- tryCatch({
    appc::predict_pm25(s2_cell, date_list)
  }, error = function(e) {
    list(error = "Prediction failed", details = e$message)
  })
  
  return(result)
}