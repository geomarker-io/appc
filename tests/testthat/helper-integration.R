skip_if_not_integration <- function() {
  skip_if(
    Sys.getenv("APPC_RUN_INTEGRATION_TESTS") != "true",
    "integration test"
  )
}
