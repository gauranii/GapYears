# Figure 5: "Gap trends and projections" -- each country's rate of change
# in the gap over 2000-2021, by region (a), and a projection out to 2100 (b).
#
# The paper does not disclose its projection method, so panel (b) is this
# repo's own naive linear extrapolation of each region's mean gap trend,
# clearly labeled as such -- not a reproduction of the paper's approach,
# which could be a more sophisticated time-series model for all this repo
# can tell from the methods text alone. Treat the 2100 endpoint as an
# illustration of what a straight-line extrapolation implies, not a
# forecast.

library(dplyr)
library(tidyr)
library(ggplot2)

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

dataset <- read.csv("data_processed/analysis_dataset.csv")

## --- Panel a: per-country linear trend in the gap, 2000-2021, by region ---

country_trends <- dataset %>%
  group_by(iso3, region) %>%
  filter(n() >= 10) %>%  # require a reasonable number of years to fit a trend
  summarise(
    slope = coef(lm(gap ~ year, data = pick(everything())))[["year"]],
    .groups = "drop"
  )

region_order <- country_trends %>%
  group_by(region) %>%
  summarise(median_slope = median(slope), .groups = "drop") %>%
  arrange(median_slope) %>%
  pull(region)

fig5a <- ggplot(country_trends %>% mutate(region = factor(region, levels = region_order)),
                 aes(x = region, y = slope)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
  geom_boxplot(outlier.shape = NA, fill = "grey90") +
  geom_jitter(width = 0.15, alpha = 0.5, size = 1) +
  labs(title = "Per-country linear trend in the healthspan-lifespan gap, 2000-2021",
       x = NULL, y = "Change in gap per year") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

ggsave("output/figures/fig5a_gap_trend_by_region.png", fig5a, width = 9, height = 6, dpi = 150)

## --- Panel b: naive linear extrapolation of regional mean gap to 2100 -----

regional_yearly <- dataset %>%
  group_by(region, year) %>%
  summarise(mean_gap = mean(gap, na.rm = TRUE), .groups = "drop")

project_region <- function(df) {
  fit <- lm(mean_gap ~ year, data = df)
  future_years <- data.frame(year = seq(min(df$year), 2100))
  pred <- predict(fit, newdata = future_years, interval = "confidence")
  bind_cols(future_years, as.data.frame(pred))
}

projections <- regional_yearly %>%
  group_by(region) %>%
  group_modify(~ project_region(.x)) %>%
  ungroup()

fig5b <- ggplot(projections, aes(x = year, y = fit, color = region, fill = region)) +
  geom_ribbon(aes(ymin = lwr, ymax = upr), alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = max(dataset$year), linetype = "dotted", color = "grey50") +
  labs(
    title = "Naive linear extrapolation of the regional gap to 2100",
    subtitle = "This repo's own straight-line projection, not the paper's undisclosed method -- illustrative only",
    x = NULL, y = "Projected mean gap (years)", color = "Region", fill = "Region"
  ) +
  theme_minimal()

ggsave("output/figures/fig5b_gap_projection_2100.png", fig5b, width = 10, height = 6.5, dpi = 150)

message("Wrote fig5a, fig5b to output/figures/")
