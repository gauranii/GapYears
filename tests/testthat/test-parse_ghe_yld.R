## parse_ghe_yld_raw() (R/04_pull_disease_burden.R) is the riskiest parsing logic
## in the repo: it locates the header row by string match, infers outline depth
## from *which* of 5 columns is non-NA, and slices country columns by fixed
## position. If WHO ever reshuffles a column, this fails silently -- wrong depth,
## wrong causes, no error -- rather than loudly. This builds a small synthetic
## `raw` data frame in the exact shape read_excel() would hand back (so no xlsx
## fixture file/writer dependency is needed) and checks the arithmetic and the
## row filtering by hand.

library(dplyr)
suppressMessages(library(tidyr))
source("../../R/04_pull_disease_burden.R")

## Layout (see R/04's own header comment for the real file's column meaning):
##   col 1        = sex block label ("Persons" / "Males" / "Females") on data rows,
##                  or a free-text marker cell used only to locate the header row
##   col 2        = cause code
##   cols 3-7     = cause name, in whichever column matches the outline depth
##                  (depth = that column's index among 3:7)
##   cols 8+      = one country per column; row `iso3_row` holds ISO3 codes
##
## Fixture: 3 countries (AAA/BBB/CCC), one Population row (depth 2, name in col 4),
## one non-Population depth-2 row ("All Causes", also col 4, to check it's excluded
## from the depth-3 extraction), two depth-3 causes (name in col 5), and Males/
## Females blocks that must be excluded entirely (only "Persons" is parsed).
build_fixture <- function() {
  data.frame(
    V1 = c("Country or area", NA,
           "Persons", "Persons", "Persons", "Persons",
           "Males", "Females"),
    V2 = c(NA, NA, NA, NA, "101", "102", "101", "101"),
    V3 = NA_character_,
    V4 = c(NA, NA, "Population", "All Causes", NA, NA, NA, NA),
    V5 = c(NA, NA, NA, NA, "Cause X", "Cause Y", "Cause X", "Cause X"),
    V6 = NA_character_,
    V7 = NA_character_,
    V8 = c(NA, "AAA", "1000", "999", "10", "1", "999", "888"),
    V9 = c(NA, "BBB", "2000", "999", "20", "4", "999", "888"),
    V10 = c(NA, "CCC", "500", "999", "5", "0.5", "999", "888"),
    stringsAsFactors = FALSE
  )
}

test_that("depth-3 causes are extracted for Persons only, with correct per-1000 rates", {
  result <- parse_ghe_yld_raw(build_fixture(), year = 2099)

  expect_setequal(unique(result$cause_name), c("Cause X", "Cause Y"))
  expect_setequal(unique(result$iso3), c("AAA", "BBB", "CCC"))
  expect_equal(nrow(result), 6)  ## 2 causes x 3 countries
  expect_true(all(result$year == 2099))

  get_rate <- function(cause, country) {
    result$yld_per_1000[result$cause_name == cause & result$iso3 == country]
  }
  ## Cause X: 10/20/5 (thousands) over population 1000/2000/500 (thousands) -> 10 per 1000 for all three
  expect_equal(get_rate("Cause X", "AAA"), 10)
  expect_equal(get_rate("Cause X", "BBB"), 10)
  expect_equal(get_rate("Cause X", "CCC"), 10)
  ## Cause Y: 1/4/0.5 over the same populations -> 1, 2, 1
  expect_equal(get_rate("Cause Y", "AAA"), 1)
  expect_equal(get_rate("Cause Y", "BBB"), 2)
  expect_equal(get_rate("Cause Y", "CCC"), 1)
})

test_that("depth-2 rows (Population, All Causes) are excluded from the cause output", {
  result <- parse_ghe_yld_raw(build_fixture(), year = 2099)
  expect_false("Population" %in% result$cause_name)
  expect_false("All Causes" %in% result$cause_name)
})

test_that("Males/Females blocks never leak into the Persons-only output", {
  result <- parse_ghe_yld_raw(build_fixture(), year = 2099)
  ## Males/Females rows carry a sentinel value (999) that would appear if the
  ## sex filter were broken.
  expect_false(999 %in% result$yld_per_1000)
})

test_that("cause_code is carried through as numeric", {
  result <- parse_ghe_yld_raw(build_fixture(), year = 2099)
  expect_equal(sort(unique(result$cause_code)), c(101, 102))
})
