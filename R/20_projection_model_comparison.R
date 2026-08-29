#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Compare Projection Methods for the 2100 Gap Forecast
#------------------------------------------------------------------------------------------


# Fig5b's naive linear extrapolation is one modeling choice among several
# reasonable ones. The paper reports a single number, its gap projected to
# widen 22% globally by 2100, without disclosing what forecasting method
# produced it. Rather than guess at that method (already declined in
# R/10_figure5.R), this script asks a different, answerable question: how
# much does the 2100 endpoint move if a different, equally defensible
# time-series method is used on the same 22 years of regional data. Three
# methods, on each region's 2000-2021 mean-gap series:
#   1. Linear (same as R/10_figure5.R's fig5b, included here for comparison)
#   2. ARIMA, order chosen automatically per region by forecast::auto.arima
#   3. ETS (exponential smoothing / Holt's linear method), forecast::ets
# This is NOT an attempt to guess or reproduce the paper's own method. It is
# an illustration of how much a "22% by 2100" style number depends on which
# reasonable method is chosen, which is the point.

library(dplyr)
library(tidyr)
library(ggplot2)
library(forecast)

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

dataset <- read.csv("data_processed/analysis_dataset.csv")
LAST_YEAR <- max(dataset$year)
HORIZON_YEAR <- 2100

regional_yearly <- dataset %>%
  group_by(region, year) %>%
  summarise(mean_gap = mean(gap, na.rm = TRUE), .groups = "drop") %>%
  arrange(region, year)

## --- Method 1: linear (same construction as R/10_figure5.R) ---------------

project_linear <- function(df) {
  fit <- lm(mean_gap ~ year, data = df)
  future_years <- data.frame(year = (LAST_YEAR + 1):HORIZON_YEAR)
  pred <- predict(fit, newdata = future_years, interval = "confidence")
  bind_cols(future_years, as.data.frame(pred)) %>%
    rename(fit = fit, lwr = lwr, upr = upr)
}

## --- Method 2: ARIMA, auto-selected order per region -----------------------

project_arima <- function(df) {
  ts_obj <- ts(df$mean_gap, start = min(df$year), frequency = 1)
  fit <- auto.arima(ts_obj)
  h <- HORIZON_YEAR - LAST_YEAR
  fc <- forecast(fit, h = h, level = 95)
  data.frame(
    year = (LAST_YEAR + 1):HORIZON_YEAR,
    fit = as.numeric(fc$mean),
    lwr = as.numeric(fc$lower),
    upr = as.numeric(fc$upper)
  )
}

## --- Method 3: ETS / exponential smoothing ---------------------------------

project_ets <- function(df) {
  ts_obj <- ts(df$mean_gap, start = min(df$year), frequency = 1)
  fit <- ets(ts_obj)
  h <- HORIZON_YEAR - LAST_YEAR
  fc <- forecast(fit, h = h, level = 95)
  data.frame(
    year = (LAST_YEAR + 1):HORIZON_YEAR,
    fit = as.numeric(fc$mean),
    lwr = as.numeric(fc$lower),
    upr = as.numeric(fc$upper)
  )
}

run_method <- function(method_name, method_fn) {
  regional_yearly %>%
    group_by(region) %>%
    group_modify(~ method_fn(.x)) %>%
    ungroup() %>%
    mutate(method = method_name)
}

projections <- bind_rows(
  run_method("Linear", project_linear),
  run_method("ARIMA", project_arima),
  run_method("ETS", project_ets)
)

## --- Figure: faceted by region, one line + ribbon per method --------------

fig5c <- ggplot() +
  geom_line(data = regional_yearly, aes(x = year, y = mean_gap), color = "black", linewidth = 0.6) +
  geom_ribbon(data = projections, aes(x = year, ymin = lwr, ymax = upr, fill = method), alpha = 0.15) +
  geom_line(data = projections, aes(x = year, y = fit, color = method), linewidth = 0.8) +
  geom_vline(xintercept = LAST_YEAR, linetype = "dotted", color = "grey50") +
  facet_wrap(~ region, scales = "free_y") +
  labs(
    title = "How much the 2100 gap projection depends on model choice",
    subtitle = "Same 22 years of regional data, three projection methods -- none reproduces the paper's undisclosed method",
    x = NULL, y = "Mean gap (years)", color = "Method", fill = "Method"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave("output/figures/fig5c_projection_model_comparison.png", fig5c, width = 11, height = 7, dpi = 150)

## --- Table: 2100 endpoint by region x method, and the spread across methods

endpoint_2100 <- projections %>%
  filter(year == HORIZON_YEAR) %>%
  select(region, method, fit) %>%
  pivot_wider(names_from = method, values_from = fit) %>%
  mutate(
    range_across_methods = pmax(Linear, ARIMA, ETS) - pmin(Linear, ARIMA, ETS)
  ) %>%
  arrange(desc(range_across_methods))

write.csv(endpoint_2100, "output/tables/projection_2100_by_method.csv", row.names = FALSE)

## --- Global (simple across-region average) % change 2021 -> 2100, one     ---
## number per method, for direct comparison against the paper's "22% by    ---
## 2100" headline. This is a simple mean across regions, not population-   ---
## weighted, since neither this repo nor (as far as its methods section    ---
## says) the paper's own 22% figure is confirmed to be population-weighted.

global_2021 <- regional_yearly %>% filter(year == LAST_YEAR) %>% summarise(m = mean(mean_gap)) %>% pull(m)

global_2100_by_method <- projections %>%
  filter(year == HORIZON_YEAR) %>%
  group_by(method) %>%
  summarise(global_mean_2100 = mean(fit), .groups = "drop") %>%
  mutate(
    pct_change_from_2021 = 100 * (global_mean_2100 - global_2021) / global_2021
  )

write.csv(global_2100_by_method, "output/tables/projection_2100_global_pct_change.csv", row.names = FALSE)

sink("output/tables/projection_model_comparison_summary.txt")
cat("2100 gap projection, three methods (Linear / ARIMA / ETS), by region\n")
cat("NOT an attempt to reproduce the paper's own undisclosed projection method.\n")
cat("This asks how much the 2100 endpoint moves under different reasonable\n")
cat("choices, using the same 2000-", LAST_YEAR, " regional data throughout. See README.\n\n", sep = "")

cat("-- 2100 projected mean gap by region and method, and the range across methods --\n")
print(endpoint_2100)

cat("\n-- Global (simple across-region mean) gap in", LAST_YEAR, ": ", round(global_2021, 3), "--\n")
cat("\n-- Global 2100 projection and implied % change from", LAST_YEAR, ", by method --\n")
cat("(the paper's own headline claim is 22% global widening by 2100)\n")
print(global_2100_by_method)
sink()

message("Wrote fig5c_projection_model_comparison.png, projection_2100_by_method.csv, ",
        "projection_2100_global_pct_change.csv, projection_model_comparison_summary.txt")
message("Global % change 2021->2100 by method: ",
        paste(sprintf("%s=%.1f%%", global_2100_by_method$method, global_2100_by_method$pct_change_from_2021), collapse = ", "))
