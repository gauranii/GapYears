## combine_dataset() (R/02_build_dataset.R) is the join/gap-calculation core of
## build_dataset(), pulled out so it can be tested against small synthetic
## per-indicator data frames instead of live WHO API pulls.

library(dplyr)

## R/02_build_dataset.R itself does source("R/01_pull_data.R"), relative to the
## repo root -- switch there just for this source() call (testthat runs test
## files with the working directory set to tests/testthat/).
old_wd <- setwd("../..")
source("R/02_build_dataset.R")
setwd(old_wd)

test_that("a country present in LE but missing from HALE is dropped (inner join)", {
  le <- data.frame(iso3 = c("AAA", "BBB"), region = c("Africa", "Africa"),
                    year = c(2019, 2019), life_expectancy = c(60, 65))
  hale <- data.frame(iso3 = "AAA", year = 2019, healthy_life_expectancy = 52)
  gdp <- data.frame(iso3 = character(), year = integer(), health_exp_pct_gdp = numeric())

  result <- combine_dataset(le, hale, gdp)

  expect_equal(nrow(result), 1)
  expect_equal(result$iso3, "AAA")
})

test_that("a country missing GDP data is kept, with NA gdp (left join, not inner)", {
  le <- data.frame(iso3 = "AAA", region = "Africa", year = 2019, life_expectancy = 60)
  hale <- data.frame(iso3 = "AAA", year = 2019, healthy_life_expectancy = 52)
  gdp <- data.frame(iso3 = character(), year = integer(), health_exp_pct_gdp = numeric())

  result <- combine_dataset(le, hale, gdp)

  expect_equal(nrow(result), 1)
  expect_true(is.na(result$health_exp_pct_gdp))
})

test_that("gap is life_expectancy minus healthy_life_expectancy", {
  le <- data.frame(iso3 = "AAA", region = "Africa", year = 2019, life_expectancy = 60)
  hale <- data.frame(iso3 = "AAA", year = 2019, healthy_life_expectancy = 52)
  gdp <- data.frame(iso3 = "AAA", year = 2019, health_exp_pct_gdp = 5.5)

  result <- combine_dataset(le, hale, gdp)

  expect_equal(result$gap, 8)
})

test_that("rows where the joined gap would be NA are dropped", {
  ## HALE present but NA (e.g. WHO reported the indicator as missing rather than
  ## omitting the row entirely) must not survive as a row with gap = NA.
  le <- data.frame(iso3 = "AAA", region = "Africa", year = 2019, life_expectancy = 60)
  hale <- data.frame(iso3 = "AAA", year = 2019, healthy_life_expectancy = NA_real_)
  gdp <- data.frame(iso3 = character(), year = integer(), health_exp_pct_gdp = numeric())

  result <- combine_dataset(le, hale, gdp)

  expect_equal(nrow(result), 0)
})

test_that("a duplicate (iso3, year) row in an input indicator does not multiply the joined output", {
  ## If WHO's API ever returns two rows for the same country-year (e.g. a stale
  ## and a revised estimate), an un-deduplicated inner_join()/left_join() would
  ## silently cross-multiply into 2 (or 4) output rows for that country-year
  ## instead of 1. combine_dataset() distinct()s each input first specifically
  ## to guard against that.
  le <- data.frame(iso3 = c("AAA", "AAA"), region = c("Africa", "Africa"),
                    year = c(2019, 2019), life_expectancy = c(60, 60.1))
  hale <- data.frame(iso3 = "AAA", year = 2019, healthy_life_expectancy = 52)
  gdp <- data.frame(iso3 = character(), year = integer(), health_exp_pct_gdp = numeric())

  result <- combine_dataset(le, hale, gdp)

  expect_equal(nrow(result), 1)
})

test_that("output is sorted by region, iso3, year", {
  le <- data.frame(
    iso3 = c("BBB", "AAA", "AAA"),
    region = c("Europe", "Africa", "Africa"),
    year = c(2019, 2020, 2019),
    life_expectancy = c(70, 61, 60)
  )
  hale <- data.frame(
    iso3 = c("BBB", "AAA", "AAA"),
    year = c(2019, 2020, 2019),
    healthy_life_expectancy = c(60, 53, 52)
  )
  gdp <- data.frame(iso3 = character(), year = integer(), health_exp_pct_gdp = numeric())

  result <- combine_dataset(le, hale, gdp)

  expect_equal(result$iso3, c("AAA", "AAA", "BBB"))
  expect_equal(result$year, c(2019, 2020, 2019))
})
