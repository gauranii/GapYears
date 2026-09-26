## R/22_projection_un_wpp.R reproduces the paper's 2100 recipe. The two places
## it can go quietly wrong: the WPP filter letting aggregate rows (regions,
## income groups) or non-medium variants through, and the per-country fit/
## projection arithmetic. Both are checked here on small synthetic inputs.

GAPYEARS_TESTING <- TRUE
suppressMessages(library(dplyr))
source("../../R/22_projection_un_wpp.R", local = TRUE)

test_that("parse_wpp_lex keeps medium-variant country rows only", {
  raw <- data.frame(
    ISO3_code   = c("AAA", "AAA", "", "BBB", "BBB"),
    LocTypeName = c("Country/Area", "Country/Area", "Region", "Country/Area", "Country/Area"),
    Variant     = c("Medium", "Medium", "Medium", "Medium", "High"),
    Time        = c(2020, 2100, 2020, 2020, 2020),
    LEx         = c(70, 80, 65, 60, 99),
    stringsAsFactors = FALSE
  )
  out <- parse_wpp_lex(raw)
  expect_equal(nrow(out), 3)
  expect_setequal(out$iso3, c("AAA", "BBB"))
  expect_equal(out$lex_wpp[out$iso3 == "BBB"], 60)
})

test_that("fit_country_gap_models recovers a known line and skips thin countries", {
  dataset <- data.frame(
    iso3 = c(rep("AAA", 4), rep("BBB", 2)),
    region = c(rep("R1", 4), rep("R2", 2)),
    year = c(2000:2003, 2000:2001),
    life_expectancy = c(60, 62, 64, 66, 70, 71),
    gap = c(8, 8.4, 8.8, 9.2, 9, 9.1)
  )
  models <- fit_country_gap_models(dataset, years = 2000:2003)
  expect_equal(models$iso3, "AAA")
  expect_equal(models$slope, 0.2, tolerance = 1e-10)
  expect_equal(models$intercept, -4, tolerance = 1e-10)
})

test_that("project_gap applies each country's own line to WPP life expectancy", {
  models <- data.frame(iso3 = "AAA", region = "R1", intercept = -4, slope = 0.2, n_years = 4)
  lex <- data.frame(iso3 = c("AAA", "AAA", "ZZZ"), year = c(2050, 2100, 2100), lex_wpp = c(75, 80, 90))
  proj <- project_gap(models, lex)
  expect_equal(nrow(proj), 2)
  expect_equal(proj$gap_projected[proj$year == 2100], 12)
})

test_that("regional_mean_sem uses mean +/- 1.96 x SEM", {
  proj <- data.frame(region = "R1", year = 2100, gap_projected = c(10, 12))
  r <- regional_mean_sem(proj)
  expect_equal(r$mean_gap, 11)
  expect_equal(r$sem, sd(c(10, 12)) / sqrt(2))
  expect_equal(r$upr - r$mean_gap, 1.96 * r$sem)
})
