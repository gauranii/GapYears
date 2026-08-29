#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Regional Descriptives, Kruskal-Wallis Test, and Gap Regression
#------------------------------------------------------------------------------------------


# Core v1 analysis: regional descriptives, Kruskal-Wallis test for regional
# differences in the healthspan-lifespan gap (with BH-adjusted pairwise
# follow-up), and a forward-selection linear regression for gap predictors.
#
# This intentionally does NOT attempt the original paper's PCA / k-means /
# random forest / Boruta disease-burden clustering, or its spatial error
# model. Both need country-level, cause-specific YLD data that isn't
# reachable through WHO's bulk API -- see README for details. This script
# covers what the LE/HALE/health-expenditure data can support on its own.

library(dplyr)

dataset <- read.csv("data_processed/analysis_dataset.csv")
latest_year <- max(dataset$year)
snapshot <- dataset %>% filter(year == latest_year)

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

## --- Regional descriptives -------------------------------------------------

regional_summary <- snapshot %>%
  group_by(region) %>%
  summarise(
    n_countries = n(),
    median_gap = median(gap, na.rm = TRUE),
    q1_gap = quantile(gap, 0.25, na.rm = TRUE),
    q3_gap = quantile(gap, 0.75, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(median_gap)

write.csv(regional_summary, "output/tables/regional_summary.csv", row.names = FALSE)

## --- Regional differences: Kruskal-Wallis + BH-adjusted pairwise Wilcoxon --

kw_test <- kruskal.test(gap ~ region, data = snapshot)

pairwise <- pairwise.wilcox.test(
  snapshot$gap, snapshot$region,
  p.adjust.method = "BH"
)

## --- Forward-selection linear regression on gap predictors -----------------
## Candidate predictors are limited to what this v1 pull actually has:
## life expectancy and health expenditure as % of GDP. The paper's third
## consistent predictor, NCD burden, needs the cause-specific YLD data
## flagged above as a phase-2 dependency.

regression_data <- snapshot %>% filter(!is.na(health_exp_pct_gdp))

null_model <- lm(gap ~ 1, data = regression_data)
full_model <- lm(gap ~ life_expectancy + health_exp_pct_gdp, data = regression_data)

forward_model <- step(
  null_model,
  scope = list(lower = null_model, upper = full_model),
  direction = "forward",
  trace = 0
)

## --- Report ------------------------------------------------------------

sink("output/tables/analysis_summary.txt")
cat("Healthspan-lifespan gap -- v1 replication summary\n")
cat("Snapshot year:", latest_year, "| n countries:", nrow(snapshot),
    "| n with complete GDP data:", nrow(regression_data), "\n\n")

cat("-- Regional gap (median, years) --\n")
print(regional_summary)

cat("\n-- Kruskal-Wallis test: gap ~ region --\n")
print(kw_test)

cat("\n-- Pairwise Wilcoxon (BH-adjusted p-values) --\n")
print(pairwise)

cat("\n-- Forward-selection regression on gap --\n")
print(summary(forward_model))
sink()

message("Wrote output/tables/regional_summary.csv and output/tables/analysis_summary.txt")
