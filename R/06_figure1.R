# Figure 1: "Healthspan lags lifespan across world regions" -- density plot
# of LE vs. HALE by region (a), a world choropleth of the gap (b), and a
# regional boxplot of the gap with points overlaid (c). Uses the latest
# available snapshot year, not the paper's 2019, per this repo's data
# section in the README.

library(dplyr)
library(tidyr)
library(ggplot2)
library(maps)
source("R/utils_map.R")

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

dataset <- read.csv("data_processed/analysis_dataset.csv")
snapshot_year <- max(dataset$year)
snapshot <- dataset %>% filter(year == snapshot_year)

## --- Panel a: density of LE vs HALE by region ------------------------------

long <- snapshot %>%
  select(region, life_expectancy, healthy_life_expectancy) %>%
  pivot_longer(c(life_expectancy, healthy_life_expectancy),
               names_to = "metric", values_to = "years") %>%
  mutate(metric = recode(metric,
    life_expectancy = "Lifespan (LE)",
    healthy_life_expectancy = "Healthspan (HALE)"
  ))

fig1a <- ggplot(long, aes(x = years, fill = metric, color = metric)) +
  geom_density(alpha = 0.4) +
  facet_wrap(~region) +
  labs(title = paste("Healthspan vs. lifespan distributions by region,", snapshot_year),
       x = "Years", y = "Density", fill = NULL, color = NULL) +
  theme_minimal() +
  theme(legend.position = "top")

ggsave("output/figures/fig1a_healthspan_lifespan_density.png", fig1a, width = 10, height = 7, dpi = 150)

## --- Panel b: world choropleth of the gap -----------------------------------

snapshot <- snapshot %>% mutate(map_region = iso3_to_map_region(iso3))

world <- map_data("world")
map_df <- world %>% left_join(snapshot %>% select(map_region, gap), by = c("region" = "map_region"))

n_unmatched <- snapshot %>% filter(!map_region %in% world$region) %>% nrow()
if (n_unmatched > 0) {
  message(n_unmatched, " countries could not be matched to a `maps` polygon and are blank on the map.")
}

fig1b <- ggplot(map_df, aes(x = long, y = lat, group = group, fill = gap)) +
  geom_polygon(color = "grey85", linewidth = 0.05) +
  scale_fill_viridis_c(name = "Gap (years)", option = "magma", direction = -1, na.value = "grey92") +
  coord_quickmap() +
  labs(title = paste("Healthspan-lifespan gap by country,", snapshot_year)) +
  theme_void() +
  theme(legend.position = "bottom")

ggsave("output/figures/fig1b_gap_world_map.png", fig1b, width = 10, height = 6, dpi = 150)

## --- Panel c: boxplot of gap by region --------------------------------------

region_order <- snapshot %>%
  group_by(region) %>%
  summarise(median_gap = median(gap), .groups = "drop") %>%
  arrange(median_gap) %>%
  pull(region)

fig1c <- ggplot(snapshot %>% mutate(region = factor(REGION_ABBR[region], levels = REGION_ABBR[region_order])),
                 aes(x = region, y = gap)) +
  geom_boxplot(outlier.shape = NA, fill = "grey90") +
  geom_jitter(width = 0.15, alpha = 0.5, size = 1.2) +
  labs(title = paste("Healthspan-lifespan gap by region,", snapshot_year),
       x = NULL, y = "Gap (years)", caption = REGION_ABBR_GUIDE) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 0), plot.caption = element_text(hjust = 0))

ggsave("output/figures/fig1c_gap_by_region_boxplot.png", fig1c, width = 9, height = 6, dpi = 150)

message("Wrote fig1a, fig1b, fig1c to output/figures/")
