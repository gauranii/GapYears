## validate_who_response() (R/01_pull_data.R) guards pull_who_indicator() against
## caching a malformed/rate-limited API response as if it were real data.

source("../../R/01_pull_data.R")

test_that("a well-formed response passes without error", {
  df <- data.frame(SpatialDimType = "COUNTRY", SpatialDim = "AAA",
                    TimeDim = 2019, NumericValue = 50)
  expect_silent(validate_who_response(df, "TEST_CODE"))
})

test_that("an empty data frame is rejected", {
  df <- data.frame(SpatialDimType = character(), SpatialDim = character(),
                    TimeDim = integer(), NumericValue = numeric())
  expect_error(validate_who_response(df, "TEST_CODE"), "no rows")
})

test_that("a non-data-frame response is rejected", {
  expect_error(validate_who_response(NULL, "TEST_CODE"), "no rows")
  expect_error(validate_who_response(list(a = 1), "TEST_CODE"), "no rows")
})

test_that("a response missing an expected column is rejected", {
  df <- data.frame(SpatialDimType = "COUNTRY", SpatialDim = "AAA", TimeDim = 2019)
  expect_error(validate_who_response(df, "TEST_CODE"), "NumericValue")
})
