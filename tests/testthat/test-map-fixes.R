## R/utils_map.R's MAP_NAME_FIXES is a hand-maintained crosswalk for the 16
## countries where countrycode() and the `maps` package's own place names
## disagree. It's exactly the kind of thing that breaks quietly on a `maps`
## package upgrade or when WHO adds a new country -- these tests turn that into
## a loud, specific failure instead of a wrong/blank country on a map figure.

library(dplyr)
suppressWarnings(library(maps))
source("../../R/utils_map.R")

map_base_names <- function() {
  m <- map("world", plot = FALSE, fill = TRUE)
  unique(sub(":.*", "", m$names))
}

test_that("every hardcoded MAP_NAME_FIXES value resolves to a real `maps` polygon name", {
  base_names <- map_base_names()
  missing <- MAP_NAME_FIXES[!MAP_NAME_FIXES %in% base_names]
  expect_length(missing, 0)
})

test_that("every country in the committed analysis dataset resolves to a non-NA map name", {
  dataset <- read.csv("../../data_processed/analysis_dataset.csv")
  countries <- unique(dataset$iso3)
  resolved <- iso3_to_map_region(countries)

  unresolved <- countries[is.na(resolved)]
  expect_length(unresolved, 0)
})

test_that("every resolved map name for the dataset's countries is a real `maps` polygon name", {
  dataset <- read.csv("../../data_processed/analysis_dataset.csv")
  countries <- unique(dataset$iso3)
  resolved <- iso3_to_map_region(countries)

  base_names <- map_base_names()
  unmatched <- countries[!is.na(resolved) & !(resolved %in% base_names)]
  expect_length(unmatched, 0)
})

test_that("every region in the committed dataset has a REGION_ABBR entry", {
  dataset <- read.csv("../../data_processed/analysis_dataset.csv")
  missing_regions <- setdiff(unique(dataset$region), names(REGION_ABBR))
  expect_length(missing_regions, 0)
})
