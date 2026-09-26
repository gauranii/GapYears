#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Reproduce the Paper's 2100 Projection via UN WPP Life Expectancy
#------------------------------------------------------------------------------------------


# The paper's methods section ("Projecting healthspan-lifespan gaps") does
# describe its projection, which R/10 and R/20 originally treated as
# undisclosed: 183 country-specific regressions of the gap on life expectancy,
# fit to the last two decades of actual values, then fed the UN World
# Population Prospects life-expectancy projections to 2100. Regional values are
# the mean of the country projections +/- 1.96 x SEM. The headline is the
# *median* gap rising 22% globally by 2100, with 2100 country values ranging
# 7.3 to 18.8 years.
#
# This script follows that recipe as written:
#   - fit window 2000-2019 (the paper's own window, and it keeps the
#     2020-2021 COVID dip in life expectancy out of the slope)
#   - gap ~ life_expectancy, one lm() per country, on WHO GHO data
#   - WPP 2024 medium variant, both-sexes life expectancy at birth (LEx), the
#     edition the paper cites (accessed Nov 2024)
#   - the % change is median(2100 projected) vs. median(2019 observed)
# Choices the paper does not state, made here: the baseline year for the %
# change (2019), and fitting on WHO life expectancy while projecting with UN
# life expectancy, which is what "UN estimates served as input" implies but
# means two sources' levels meet at the handoff. The summary also reports a
# same-source baseline (2019 projected from WPP) so that level mismatch is
# visible rather than hidden in the headline.
#
# The earlier "UN WPP: blocked" note in the README concerned the Data Portal
# API, which needs a bearer token. The WPP bulk CSV files below are a plain
# static download and need no key.

library(dplyr)
library(ggplot2)

WPP_URL <- "https://population.un.org/wpp/assets/Excel%20Files/1_Indicator%20(Standard)/CSV_FILES/WPP2024_Demographic_Indicators_Medium.csv.gz"
WPP_DIR <- "data_raw/wpp"
WPP_FILE <- "WPP2024_Demographic_Indicators_Medium.csv.gz"

## The real file is ~16MB compressed; an HTML error page would be tiny.
WPP_MIN_BYTES <- 1e6

FIT_YEARS <- 2000:2019
BASE_YEAR <- 2019
HORIZON_YEAR <- 2100

options(timeout = max(300, getOption("timeout")))

download_wpp <- function(refresh = FALSE) {
  dir.create(WPP_DIR, showWarnings = FALSE, recursive = TRUE)
  dest <- file.path(WPP_DIR, WPP_FILE)
  if (!file.exists(dest) || refresh) {
    status <- tryCatch(
      download.file(WPP_URL, dest, mode = "wb", quiet = TRUE),
      error = function(e) e
    )
    size <- if (file.exists(dest)) file.info(dest)$size else 0
    if (!identical(status, 0L) || size < WPP_MIN_BYTES) {
      unlink(dest)
      stop(
        "Download of the WPP 2024 demographic indicators file failed or returned an ",
        "unexpectedly small file (", size, " bytes). Not caching it. URL: ", WPP_URL
      )
    }
  }
  dest
}

## Keep country rows only (WPP also carries regions, income groups, SDG
## groupings, etc., all without an ISO3 code), medium variant, both-sexes LEx.
parse_wpp_lex <- function(raw) {
  raw %>%
    filter(
      LocTypeName == "Country/Area",
      !is.na(ISO3_code), ISO3_code != "",
      Variant == "Medium"
    ) %>%
    transmute(iso3 = ISO3_code, year = as.integer(Time), lex_wpp = as.numeric(LEx)) %>%
    filter(!is.na(lex_wpp)) %>%
    distinct(iso3, year, .keep_all = TRUE)
}

read_wpp_lex <- function(path) {
  raw <- read.csv(gzfile(path), stringsAsFactors = FALSE, check.names = FALSE,
                  fileEncoding = "UTF-8-BOM")
  parse_wpp_lex(raw)
}

## One lm(gap ~ life_expectancy) per country over `years`. Countries with fewer
## than 3 usable years, or no variation in life expectancy, get no model.
fit_country_gap_models <- function(dataset, years = FIT_YEARS) {
  dataset %>%
    filter(year %in% years, !is.na(gap), !is.na(life_expectancy)) %>%
    group_by(iso3, region) %>%
    filter(n() >= 3, sd(life_expectancy) > 0) %>%
    summarise(
      intercept = unname(coef(lm(gap ~ life_expectancy))[1]),
      slope = unname(coef(lm(gap ~ life_expectancy))[2]),
      n_years = n(),
      .groups = "drop"
    )
}

project_gap <- function(models, lex) {
  models %>%
    inner_join(lex, by = "iso3", relationship = "one-to-many") %>%
    mutate(gap_projected = intercept + slope * lex_wpp) %>%
    select(iso3, region, year, lex_wpp, gap_projected)
}

## Regional mean +/- 1.96 x SEM, the paper's own aggregation.
regional_mean_sem <- function(proj) {
  proj %>%
    group_by(region, year) %>%
    summarise(
      mean_gap = mean(gap_projected),
      sem = sd(gap_projected) / sqrt(n()),
      n = n(),
      .groups = "drop"
    ) %>%
    mutate(lwr = mean_gap - 1.96 * sem, upr = mean_gap + 1.96 * sem)
}

## Only run the pipeline when sourced for real, not when a test sources this
## file for its functions.
if (!exists("GAPYEARS_TESTING")) {
  dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
  dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

  dataset <- read.csv("data_processed/analysis_dataset.csv")
  lex <- read_wpp_lex(download_wpp())

  models <- fit_country_gap_models(dataset)
  proj <- project_gap(models, lex %>% filter(year >= BASE_YEAR, year <= HORIZON_YEAR))
  missing_in_wpp <- setdiff(models$iso3, lex$iso3)

  observed_base <- dataset %>% filter(year == BASE_YEAR, iso3 %in% proj$iso3, !is.na(gap))
  median_obs_base <- median(observed_base$gap)
  median_proj_base <- median(proj$gap_projected[proj$year == BASE_YEAR])
  proj_2100 <- proj %>% filter(year == HORIZON_YEAR)
  median_2100 <- median(proj_2100$gap_projected)

  pct_vs_observed <- 100 * (median_2100 - median_obs_base) / median_obs_base
  pct_vs_projected <- 100 * (median_2100 - median_proj_base) / median_proj_base

  ## Sensitivity: the same recipe fit on 2000-2021 instead of 2000-2019.
  models_2021 <- fit_country_gap_models(dataset, years = 2000:2021)
  median_2100_fit2021 <- median(project_gap(models_2021, lex %>% filter(year == HORIZON_YEAR))$gap_projected)
  pct_fit2021 <- 100 * (median_2100_fit2021 - median_obs_base) / median_obs_base

  regional <- regional_mean_sem(proj)

  write.csv(models, "output/tables/projection_un_wpp_country_models.csv", row.names = FALSE)
  write.csv(proj_2100, "output/tables/projection_un_wpp_country_2100.csv", row.names = FALSE)
  write.csv(regional, "output/tables/projection_un_wpp_regional.csv", row.names = FALSE)

  fig5b <- ggplot(regional, aes(x = year, y = mean_gap, color = region, fill = region)) +
    geom_ribbon(aes(ymin = lwr, ymax = upr), alpha = 0.15, color = NA) +
    geom_line(linewidth = 0.8) +
    labs(
      title = "Gap projected to 2100 the paper's way",
      subtitle = paste0("Per-country gap ~ life expectancy (", min(FIT_YEARS), "-", max(FIT_YEARS),
                        "), driven by UN WPP 2024 medium-variant life expectancy; regional mean +/- 1.96 SEM"),
      x = NULL, y = "Projected gap (years)", color = "Region", fill = "Region"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave("output/figures/fig5b_projection_un_wpp.png", fig5b, width = 10, height = 6, dpi = 150)

  sink("output/tables/projection_un_wpp_summary.txt")
  cat("2100 gap projection, the paper's own recipe | countries projected:", n_distinct(proj$iso3), "\n")
  cat("Per-country lm(gap ~ life_expectancy) on WHO data, ", min(FIT_YEARS), "-", max(FIT_YEARS),
      ", driven by UN WPP 2024 medium-variant LEx. See README.\n", sep = "")
  if (length(missing_in_wpp) > 0) cat("Fitted but absent from WPP:", paste(missing_in_wpp, collapse = ", "), "\n")

  cat("\n-- Per-country slopes (gap years per year of life expectancy) --\n")
  print(summary(models$slope))
  cat("Countries with a negative slope:", sum(models$slope < 0), "of", nrow(models), "\n")

  cat("\n-- Median gap --\n")
  cat("Observed ", BASE_YEAR, " (WHO):            ", round(median_obs_base, 3), "\n", sep = "")
  cat("Projected ", BASE_YEAR, " (WPP-driven):    ", round(median_proj_base, 3), "\n", sep = "")
  cat("Projected ", HORIZON_YEAR, " (WPP-driven):    ", round(median_2100, 3), "\n", sep = "")

  cat("\n-- % change in the median gap to ", HORIZON_YEAR, " (paper: 22%) --\n", sep = "")
  cat("vs. observed ", BASE_YEAR, " median:          ", round(pct_vs_observed, 1), "%\n", sep = "")
  cat("vs. WPP-driven ", BASE_YEAR, " median:        ", round(pct_vs_projected, 1), "%\n", sep = "")
  cat("Sensitivity, fit on 2000-2021 instead: ", round(pct_fit2021, 1), "% (vs. observed ", BASE_YEAR, ")\n", sep = "")

  cat("\n-- ", HORIZON_YEAR, " country range (paper: 7.3 to 18.8 years) --\n", sep = "")
  print(summary(proj_2100$gap_projected))

  cat("\n-- Regional mean projected gap, ", BASE_YEAR, " and ", HORIZON_YEAR, " --\n", sep = "")
  print(as.data.frame(regional %>% filter(year %in% c(BASE_YEAR, HORIZON_YEAR)) %>%
                        select(region, year, mean_gap, lwr, upr, n)))
  sink()

  message("Wrote fig5b_projection_un_wpp.png and projection_un_wpp_* tables")
  message(sprintf("Median gap %d -> %d: %.1f%% (paper: 22%%)", BASE_YEAR, HORIZON_YEAR, pct_vs_observed))
}
