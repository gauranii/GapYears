# Panel regression on the full 2000-2021 country-year data, as an
# alternative to R/03_analysis.R's single-year (2021) cross-sectional
# regression. The cross-sectional model asks "do countries with higher
# life expectancy and health spending have a wider gap"; a country
# fixed-effects panel model asks a different, generally more credible
# question: within the SAME country, does the gap widen in the years its
# life expectancy or health spending rises, holding everything else about
# that country (geography, history, baseline health-system quality, and
# every other time-invariant factor) fixed. Comparing the two is the point
# of this script, not picking one as "correct."

library(dplyr)
library(plm)

dataset <- read.csv("data_processed/analysis_dataset.csv")

panel_data <- dataset %>%
  filter(!is.na(health_exp_pct_gdp)) %>%
  as.data.frame()

pdata <- pdata.frame(panel_data, index = c("iso3", "year"))

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

## --- Pooled OLS: all 22 years pooled, no fixed effects, as a naive baseline
pooled <- plm(gap ~ life_expectancy + health_exp_pct_gdp, data = pdata, model = "pooling")

## --- Country fixed effects: the "within" estimator ------------------------
fe <- plm(gap ~ life_expectancy + health_exp_pct_gdp, data = pdata, model = "within")

## --- Random effects, for the Hausman test to compare against --------------
re <- plm(gap ~ life_expectancy + health_exp_pct_gdp, data = pdata, model = "random")

hausman <- phtest(fe, re)

## --- Compare against R/03_analysis.R's single-year (latest year) OLS ------
latest_year <- max(panel_data$year)
snapshot <- panel_data %>% filter(year == latest_year)
cross_sectional <- lm(gap ~ life_expectancy + health_exp_pct_gdp, data = snapshot)

sink("output/tables/panel_regression_summary.txt")
cat("Panel regression on the full 2000-2021 country-year data\n")
cat("(n countries:", length(unique(panel_data$iso3)),
    "| n country-years:", nrow(panel_data), ")\n\n")

cat("This compares three ways of asking the same question, gap ~ life_expectancy +\n")
cat("health_exp_pct_gdp, not picking one as correct:\n")
cat("  1. Cross-sectional OLS on the", latest_year, "snapshot alone (R/03_analysis.R's model)\n")
cat("  2. Pooled OLS across all 22 years (ignores that observations from the\n")
cat("     same country are not independent)\n")
cat("  3. Country fixed-effects (within-country variation only, i.e. does a rise in a\n")
cat("     country's own life expectancy or spending coincide with a change in its own gap)\n\n")

cat("== 1. Cross-sectional OLS,", latest_year, "only ==\n")
print(summary(cross_sectional)$coefficients)

cat("\n== 2. Pooled OLS, all years ==\n")
print(summary(pooled)$coefficients)

cat("\n== 3. Country fixed effects (within), all years ==\n")
print(summary(fe)$coefficients)

cat("\n== Hausman test: fixed vs. random effects ==\n")
print(hausman)
cat("A significant Hausman test (p < 0.05) favors fixed effects: the random-effects\n")
cat("assumption, that a country's own unobserved characteristics are uncorrelated\n")
cat("with its life expectancy and spending, is rejected. That is the expected result\n")
cat("here -- a country's baseline health-system quality is almost certainly correlated\n")
cat("with both its life expectancy and its gap.\n")
sink()

## Save the three coefficient tables together for the writeup, not just the
## sink() text dump above.
coef_table <- bind_rows(
  as.data.frame(summary(cross_sectional)$coefficients) %>%
    mutate(term = rownames(summary(cross_sectional)$coefficients), model = "cross_sectional_latest_year"),
  as.data.frame(summary(pooled)$coefficients) %>%
    mutate(term = rownames(summary(pooled)$coefficients), model = "pooled_ols_all_years"),
  as.data.frame(summary(fe)$coefficients) %>%
    mutate(term = rownames(summary(fe)$coefficients), model = "country_fixed_effects")
) %>%
  select(model, term, everything())

write.csv(coef_table, "output/tables/panel_regression_coefficients.csv", row.names = FALSE)

message("Wrote output/tables/panel_regression_summary.txt and panel_regression_coefficients.csv")
message("Hausman p-value: ", signif(hausman$p.value, 3),
        " (", ifelse(hausman$p.value < 0.05, "favors fixed effects", "favors random effects"), ")")
