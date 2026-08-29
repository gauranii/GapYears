#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Figure 2 - Larger/Smaller-Than-Predicted Gap Maps
#------------------------------------------------------------------------------------------


# Figure 2: "Healthspan-lifespan gap deviation" -- countries with a larger-
# or smaller-than-predicted gap, each with a map and a regional-composition
# donut. "Predicted" here comes from this repo's own forward-selection
# regression in R/03_analysis.R (gap ~ life_expectancy + health_exp_pct_gdp).
# The original paper's model also includes NCD burden as a predictor, which
# this repo's v1 regression does not have, so the exact set of over/under
# countries will not match the paper's -- the residual-based approach is
# the same, the predictor set behind it is narrower.

library(dplyr)
library(ggplot2)
library(maps)
source("R/utils_map.R")

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

dataset <- read.csv("data_processed/analysis_dataset.csv")
snapshot_year <- max(dataset$year)
snapshot <- dataset %>%
  filter(year == snapshot_year, !is.na(health_exp_pct_gdp)) %>%
  mutate(map_region = iso3_to_map_region(iso3))

model <- lm(gap ~ life_expectancy + health_exp_pct_gdp, data = snapshot)
snapshot$residual <- resid(model)
snapshot$deviation <- ifelse(snapshot$residual > 0, "Larger than predicted", "Smaller than predicted")

world <- map_data("world")

plot_deviation_map <- function(direction_label, fill_color) {
  sub <- snapshot %>% filter(deviation == direction_label)
  map_df <- world %>%
    mutate(highlighted = region %in% sub$map_region)

  ggplot(map_df, aes(x = long, y = lat, group = group, fill = highlighted)) +
    geom_polygon(color = "grey85", linewidth = 0.05) +
    scale_fill_manual(values = c(`TRUE` = fill_color, `FALSE` = "grey92"), guide = "none") +
    coord_quickmap() +
    labs(title = paste0(direction_label, " gap (n = ", nrow(sub), "), ", snapshot_year)) +
    theme_void()
}

fig2a <- plot_deviation_map("Larger than predicted", "#b2182b")
ggsave("output/figures/fig2a_larger_than_predicted_map.png", fig2a, width = 9, height = 5.5, dpi = 150)

fig2b <- plot_deviation_map("Smaller than predicted", "#2166ac")
ggsave("output/figures/fig2b_smaller_than_predicted_map.png", fig2b, width = 9, height = 5.5, dpi = 150)

## --- Regional composition donuts for each deviation group -----------------

donut_data <- snapshot %>%
  count(deviation, region) %>%
  group_by(deviation) %>%
  mutate(share = n / sum(n)) %>%
  ungroup()

fig2_donuts <- ggplot(donut_data, aes(x = 2, y = share, fill = region)) +
  geom_col(color = "white") +
  coord_polar(theta = "y") +
  xlim(0.5, 2.5) +
  facet_wrap(~deviation) +
  labs(title = paste0("Regional composition of gap-deviation groups, ", snapshot_year),
       fill = "Region", x = NULL, y = NULL) +
  theme_void() +
  theme(legend.position = "right")

ggsave("output/figures/fig2c_deviation_regional_composition.png", fig2_donuts, width = 10, height = 5.5, dpi = 150)

message("Wrote fig2a, fig2b, fig2c to output/figures/")
