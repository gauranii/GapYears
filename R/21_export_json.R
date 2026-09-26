#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Export Figure 1 and Figure 2d's country-level data as JSON, for
#                         the interactive d3 maps on statistical.systems (replaces the
#                         static fig1b and fig2d choropleths for those two views).
#------------------------------------------------------------------------------------------

library(dplyr)
library(countrycode)
library(jsonlite)

dir.create("output/json", showWarnings = FALSE, recursive = TRUE)

dataset <- read.csv("data_processed/analysis_dataset.csv")
snapshot_year <- max(dataset$year)
snapshot <- dataset %>%
  filter(year == snapshot_year) %>%
  mutate(
    name = countrycode(iso3, "iso3c", "country.name"),
    id = as.integer(countrycode(iso3, "iso3c", "iso3n"))  # numeric ISO code: what world-atlas topojson keys features by
  ) %>%
  filter(!is.na(id)) %>%
  select(id, iso3, name, region, life_expectancy, healthy_life_expectancy, gap) %>%
  mutate(
    life_expectancy = round(life_expectancy, 2),
    healthy_life_expectancy = round(healthy_life_expectancy, 2),
    gap = round(gap, 2)
  ) %>%
  arrange(id)

out <- list(
  year = snapshot_year,
  countries = snapshot
)

write_json(out, "output/json/fig1_gap_by_country.json", dataframe = "rows", auto_unbox = TRUE, digits = 2)

message("Wrote output/json/fig1_gap_by_country.json (", nrow(snapshot), " countries, year ", snapshot_year, ")")

## --- Figure 2d: OLS vs. spatial-error-model deviation classification -------

spatial <- read.csv("output/tables/spatial_model_deviations.csv") %>%
  mutate(
    name = countrycode(iso3, "iso3c", "country.name"),
    id = as.integer(countrycode(iso3, "iso3c", "iso3n"))
  ) %>%
  filter(!is.na(id)) %>%
  select(id, iso3, name, region, lon, lat, ols_residual, ols_deviation,
         gls_residual, gls_deviation, flipped) %>%
  mutate(
    lon = round(lon, 2),
    lat = round(lat, 2),
    ols_residual = round(ols_residual, 3),
    gls_residual = round(gls_residual, 3)
  ) %>%
  arrange(id)

out_spatial <- list(
  year = snapshot_year,
  countries = spatial
)

write_json(out_spatial, "output/json/fig2d_spatial_deviation.json", dataframe = "rows", auto_unbox = TRUE, digits = 3)

message("Wrote output/json/fig2d_spatial_deviation.json (", nrow(spatial), " countries, ",
        sum(spatial$flipped), " flipped)")
