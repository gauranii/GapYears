# A spatial error model for the same gap ~ life_expectancy +
# health_exp_pct_gdp regression used in R/03_analysis.R and R/07_figure2.R,
# as a spatial-autocorrelation-aware alternative to that plain-OLS
# residual map.
#
# CAVEAT, stated here and in the README: the paper's own spatial error
# model uses a geographic adjacency/weights structure it never discloses.
# This script builds its own -- there is no reason to expect the resulting
# deviation map to match the paper's Figure 2 supplement (S15-S16)
# specifically. What it can show honestly is whether accounting for
# spatial autocorrelation at all changes which countries look larger- or
# smaller-than-predicted, relative to the plain-OLS version.
#
# Approach: spdep/spatialreg, the standard spatial-econometrics stack, pull
# in `sf`, which fails to build from source in this nix environment (the
# same broken GDAL/libtiff/PROJ linkage documented in R/utils_map.R for the
# choropleth maps). Falls back to nlme::gls() with a corExp() spatial
# correlation structure over country centroid lon/lat -- an exponential
# spatial-decay error covariance, which is the same modeling idea as a
# spatial error model (errors correlated by geographic distance) without
# needing a formal adjacency matrix or the sf/spdep toolchain.
#
# Country centroids are a simple mean of each `maps` polygon's vertices
# (multi-polygon countries averaged across their pieces), not a proper
# area-weighted centroid. Fine for "is this country near that one," not
# precise enough for anything requiring real geographic accuracy.

library(dplyr)
library(nlme)
library(ggplot2)
library(maps)
source("R/utils_map.R")

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)

## --- Country centroids from `maps`' polygon vertices -----------------------

m <- map("world", plot = FALSE, fill = TRUE)
poly_group <- cumsum(is.na(m$x))
verts <- data.frame(x = m$x, y = m$y, poly_group = poly_group)
verts <- verts[!is.na(verts$x), ]

poly_centroids <- verts %>%
  group_by(poly_group) %>%
  summarise(x = mean(x), y = mean(y), .groups = "drop") %>%
  mutate(name = m$names[poly_group + 1], base_name = sub(":.*", "", name))

centroids <- poly_centroids %>%
  group_by(base_name) %>%
  summarise(lon = mean(x), lat = mean(y), .groups = "drop") %>%
  rename(map_region = base_name)

## --- Data: same snapshot and predictors as 03_analysis.R / 07_figure2.R ---

dataset <- read.csv("data_processed/analysis_dataset.csv")
snapshot_year <- max(dataset$year)
snapshot <- dataset %>%
  filter(year == snapshot_year, !is.na(health_exp_pct_gdp)) %>%
  mutate(map_region = iso3_to_map_region(iso3)) %>%
  inner_join(centroids, by = "map_region")

message(
  nrow(dataset %>% filter(year == snapshot_year, !is.na(health_exp_pct_gdp))) - nrow(snapshot),
  " of ",
  nrow(dataset %>% filter(year == snapshot_year, !is.na(health_exp_pct_gdp))),
  " countries dropped for missing a centroid match (same 16-country name-matching gap as the choropleth maps, see utils_map.R)"
)

## --- OLS baseline (identical model to 07_figure2.R) ------------------------

ols_model <- lm(gap ~ life_expectancy + health_exp_pct_gdp, data = snapshot)
snapshot$ols_residual <- resid(ols_model)
snapshot$ols_deviation <- ifelse(snapshot$ols_residual > 0, "Larger than predicted", "Smaller than predicted")

## --- Spatial error model: GLS with an exponential spatial correlation -----
## structure over country centroids, nugget included since two countries
## with identical coordinates (there are none here, but adjacent small
## countries can sit very close) shouldn't be forced to a correlation of
## exactly 1.

gls_model <- gls(
  gap ~ life_expectancy + health_exp_pct_gdp,
  data = snapshot,
  correlation = corExp(form = ~ lon + lat, nugget = TRUE)
)

snapshot$gls_residual <- resid(gls_model, type = "response")
snapshot$gls_deviation <- ifelse(snapshot$gls_residual > 0, "Larger than predicted", "Smaller than predicted")
snapshot$flipped <- snapshot$ols_deviation != snapshot$gls_deviation

## --- Map of the spatial-model deviation, faceted larger/smaller -----------

world <- map_data("world")

map_df <- world %>%
  left_join(
    snapshot %>% select(map_region, gls_deviation),
    by = c("region" = "map_region")
  )

fig2d <- ggplot(map_df %>% filter(!is.na(gls_deviation)),
                 aes(x = long, y = lat, group = group, fill = gls_deviation)) +
  geom_polygon(color = "grey85", linewidth = 0.05) +
  geom_polygon(
    data = map_df %>% filter(is.na(gls_deviation)),
    fill = "grey92", color = "grey85", linewidth = 0.05
  ) +
  scale_fill_manual(values = c(
    "Larger than predicted" = "#b2182b",
    "Smaller than predicted" = "#2166ac"
  )) +
  coord_quickmap() +
  labs(
    title = paste0("Spatial-error-model gap deviation, ", snapshot_year),
    subtitle = "This repo's own corExp() spatial weights, not the paper's undisclosed structure",
    fill = NULL
  ) +
  theme_void() +
  theme(legend.position = "bottom")

ggsave("output/figures/fig2d_spatial_adjusted_map.png", fig2d, width = 10, height = 6.5, dpi = 150)

## --- Report ------------------------------------------------------------

flip_table <- snapshot %>%
  filter(flipped) %>%
  select(iso3, region, ols_deviation, gls_deviation, ols_residual, gls_residual) %>%
  arrange(region)

write.csv(flip_table, "output/tables/spatial_model_flips.csv", row.names = FALSE)
write.csv(
  snapshot %>% select(iso3, region, lon, lat, ols_residual, ols_deviation, gls_residual, gls_deviation, flipped),
  "output/tables/spatial_model_deviations.csv", row.names = FALSE
)

sink("output/tables/spatial_model_summary.txt")
cat("Spatial error model (nlme::gls + corExp on country centroids), ", snapshot_year,
    "| n countries:", nrow(snapshot), "\n")
cat("NOT a reproduction of the paper's spatial error model -- own centroid-based\n")
cat("exponential correlation structure, own country set. See README.\n\n")

cat("-- GLS model summary --\n")
print(summary(gls_model))

cat("\n-- OLS vs. spatial-model deviation classification --\n")
print(table(OLS = snapshot$ols_deviation, Spatial = snapshot$gls_deviation))

cat("\n", nrow(flip_table), "of", nrow(snapshot), "countries flip larger/smaller-than-predicted",
    "once spatial autocorrelation is accounted for.\n\n")

cat("-- Countries that flip --\n")
print(flip_table)
sink()

message("Wrote fig2d_spatial_adjusted_map.png, spatial_model_flips.csv, ",
        "spatial_model_deviations.csv, spatial_model_summary.txt")
message(nrow(flip_table), " of ", nrow(snapshot), " countries flip OLS-vs-spatial classification")
