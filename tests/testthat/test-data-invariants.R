## Schema/invariant checks on the committed pipeline outputs (data_processed/).
## These don't re-verify WHO's numbers (expected to drift as WHO revises history,
## see README), just the shape and basic sanity of what the pipeline produced --
## cheap to run, and they catch an entire class of "WHO changed something
## upstream" or "a join broke" bugs immediately rather than only being noticed
## when a figure looks wrong.

library(dplyr)

WHO_REGIONS <- c("Africa", "Americas", "Eastern Mediterranean", "Europe",
                  "South-East Asia", "Western Pacific")

test_that("analysis_dataset.csv has the expected columns and types", {
  dataset <- read.csv("../../data_processed/analysis_dataset.csv")
  expect_true(all(c("iso3", "region", "year", "life_expectancy",
                     "healthy_life_expectancy", "health_exp_pct_gdp", "gap") %in% names(dataset)))
  expect_true(is.numeric(dataset$year))
  expect_true(is.numeric(dataset$gap))
})

test_that("analysis_dataset.csv has no negative gaps", {
  ## gap = life_expectancy - healthy_life_expectancy; a negative value would mean
  ## HALE exceeds LE, which is a data/join error, not a real finding.
  dataset <- read.csv("../../data_processed/analysis_dataset.csv")
  expect_true(all(dataset$gap >= 0))
})

test_that("analysis_dataset.csv years fall within the documented pull window", {
  dataset <- read.csv("../../data_processed/analysis_dataset.csv")
  expect_true(all(dataset$year >= 2000 & dataset$year <= 2021))
})

test_that("analysis_dataset.csv has no duplicate (iso3, year) rows", {
  dataset <- read.csv("../../data_processed/analysis_dataset.csv")
  expect_equal(nrow(dataset), nrow(distinct(dataset, iso3, year)))
})

test_that("analysis_dataset.csv regions are all known WHO regions", {
  dataset <- read.csv("../../data_processed/analysis_dataset.csv")
  expect_true(all(dataset$region %in% WHO_REGIONS))
})

test_that("disease_burden_long.csv has the expected columns and no negative rates", {
  burden <- read.csv("../../data_processed/disease_burden_long.csv")
  expect_true(all(c("cause_code", "cause_name", "iso3", "yld_per_1000", "year") %in% names(burden)))
  expect_true(all(burden$yld_per_1000 >= 0))
})

test_that("disease_burden_long.csv has no duplicate (iso3, cause_name, year) rows", {
  burden <- read.csv("../../data_processed/disease_burden_long.csv")
  expect_equal(nrow(burden), nrow(distinct(burden, iso3, cause_name, year)))
})

test_that("disease_burden_long.csv years are within the documented GHE pull years", {
  burden <- read.csv("../../data_processed/disease_burden_long.csv")
  expect_true(all(burden$year %in% c(2000, 2010, 2015, 2019, 2020, 2021)))
})
