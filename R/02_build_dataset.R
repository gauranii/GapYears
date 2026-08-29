#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Build Country-Year Analysis Dataset
#------------------------------------------------------------------------------------------


# Build the country-year analysis dataset: life expectancy, healthy life
# expectancy (HALE), the healthspan-lifespan gap, and health expenditure
# as a share of GDP, restricted to years where both LE and HALE are reported.

library(dplyr)
source("R/01_pull_data.R")

ANALYSIS_YEARS <- 2000:2021

build_dataset <- function() {
  le <- pull_who_indicator(indicators["life_expectancy"]) %>%
    filter(SpatialDimType == "COUNTRY", Dim1 == "SEX_BTSX", TimeDim %in% ANALYSIS_YEARS) %>%
    transmute(iso3 = SpatialDim, region = ParentLocation, year = TimeDim,
              life_expectancy = NumericValue)

  hale <- pull_who_indicator(indicators["healthy_life_expectancy"]) %>%
    filter(SpatialDimType == "COUNTRY", Dim1 == "SEX_BTSX", TimeDim %in% ANALYSIS_YEARS) %>%
    transmute(iso3 = SpatialDim, year = TimeDim, healthy_life_expectancy = NumericValue)

  gdp <- pull_who_indicator(indicators["health_exp_pct_gdp"]) %>%
    filter(SpatialDimType == "COUNTRY", TimeDim %in% ANALYSIS_YEARS) %>%
    transmute(iso3 = SpatialDim, year = TimeDim, health_exp_pct_gdp = NumericValue)

  le %>%
    inner_join(hale, by = c("iso3", "year")) %>%
    left_join(gdp, by = c("iso3", "year")) %>%
    mutate(gap = life_expectancy - healthy_life_expectancy) %>%
    filter(!is.na(gap)) %>%
    arrange(region, iso3, year)
}

if (sys.nframe() == 0) {
  dataset <- build_dataset()
  dir.create("data_processed", showWarnings = FALSE)
  write.csv(dataset, "data_processed/analysis_dataset.csv", row.names = FALSE)
  message(
    "Wrote ", nrow(dataset), " country-year rows spanning ",
    min(dataset$year), "-", max(dataset$year), " (pulled ", Sys.Date(), ")"
  )
}
