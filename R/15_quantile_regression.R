#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Quantile Regression on Gap ~ Life Expectancy + Health Spending
#------------------------------------------------------------------------------------------


# Quantile regression on the same gap ~ life_expectancy + health_exp_pct_gdp
# relationship as R/03_analysis.R's OLS and R/14_panel_regression.R's panel
# models, on the same latest-year snapshot R/03_analysis.R uses. Neither
# this repo nor the original paper attempts this; it is this repo's own
# extension, not a replication of anything.
#
# OLS answers one question: on average, how much wider is the gap for a
# one-unit increase in life expectancy or health spending. That average can
# hide a very different relationship at the top and bottom of the gap
# distribution. Quantile regression fits that relationship separately at
# several points in the distribution, so this asks whether the predictors
# matter more (or less) for countries that already have a narrow gap versus
# countries that already have a wide one, not just what they do on average.

library(dplyr)
library(quantreg)

dataset <- read.csv("data_processed/analysis_dataset.csv")
latest_year <- max(dataset$year)

snapshot <- dataset %>%
  filter(year == latest_year, !is.na(health_exp_pct_gdp))

TAUS <- c(0.1, 0.25, 0.5, 0.75, 0.9)

ols <- lm(gap ~ life_expectancy + health_exp_pct_gdp, data = snapshot)

qr_fits <- rq(gap ~ life_expectancy + health_exp_pct_gdp, tau = TAUS, data = snapshot)
qr_summary <- summary(qr_fits, se = "boot")

extract_coef <- function(one_summary, tau) {
  co <- one_summary$coefficients
  data.frame(
    tau = tau,
    term = rownames(co),
    estimate = co[, "Value"],
    std_error = co[, "Std. Error"],
    p_value = co[, "Pr(>|t|)"]
  )
}

qr_coef_table <- if (length(TAUS) == 1) {
  extract_coef(qr_summary, TAUS)
} else {
  bind_rows(Map(extract_coef, qr_summary, TAUS))
}

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write.csv(qr_coef_table, "output/tables/quantile_regression_coefficients.csv", row.names = FALSE)

## Wide table, one row per predictor, one column per quantile, for an
## at-a-glance comparison against the single OLS estimate.
wide_estimates <- qr_coef_table %>%
  filter(term != "(Intercept)") %>%
  select(term, tau, estimate) %>%
  tidyr::pivot_wider(names_from = tau, values_from = estimate, names_prefix = "tau_")

sink("output/tables/quantile_regression_summary.txt")
cat("Quantile regression, gap ~ life_expectancy + health_exp_pct_gdp,", latest_year,
    "snapshot | n countries:", nrow(snapshot), "\n")
cat("NOT attempted by the paper -- this repo's own extension. Bootstrapped\n")
cat("standard errors (R's default rank-inversion CIs are unstable at this n).\n\n")

cat("-- OLS (for reference, same model R/03_analysis.R reports) --\n")
print(summary(ols)$coefficients)

cat("\n-- Quantile regression estimates, one row per predictor, one column per tau --\n")
print(as.data.frame(wide_estimates))

cat("\n-- Full coefficient table with standard errors and p-values --\n")
print(qr_coef_table)
sink()

message("Wrote output/tables/quantile_regression_coefficients.csv and quantile_regression_summary.txt")
