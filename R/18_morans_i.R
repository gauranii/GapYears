#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Moran's I Test for Spatial Autocorrelation in the Gap Residuals
#------------------------------------------------------------------------------------------


# Moran's I on the plain-OLS residuals from R/03_analysis.R's
# gap ~ life_expectancy + health_exp_pct_gdp regression, the same residuals
# R/07_figure2.R maps and R/12_spatial_error_model.R re-fits with a spatial
# correlation structure. This is the formal diagnostic that would motivate
# attempting a spatial model in the first place, so it belongs alongside
# that work as a companion, not a replacement for it: R/12 already fits a
# spatial error model; this asks whether the plain-OLS residuals actually
# show spatial autocorrelation at all before that model gets fit.
#
# spdep, the standard package for this, pulls in sf, which fails to build
# from source in this nix environment (the same broken GDAL/libtiff/PROJ
# linkage documented in R/utils_map.R and R/12_spatial_error_model.R). Not
# retried here for the same reason. Moran's I itself is a simple, well-known
# formula, implemented directly in base R below rather than reached for a
# package.
#
# I = (n / S0) * sum_i sum_j w_ij (x_i - xbar)(x_j - xbar) / sum_i (x_i - xbar)^2
# where w_ij are spatial weights and S0 = sum_i sum_j w_ij.
#
# Weights: inverse squared distance between country centroids (the same
# crude, `maps`-polygon-vertex-averaged centroids R/12_spatial_error_model.R
# already builds, reused here rather than re-derived, for consistency),
# capped so no country weights itself (diagonal zeroed). Inverse-distance
# weighting is chosen over a fixed k-nearest-neighbor cutoff because it
# does not require picking an arbitrary neighbor count, and it is the more
# common default for a first Moran's I pass.
#
# Significance comes from a permutation test (999 random relabelings of the
# residuals across countries, observed I compared against that null
# distribution) rather than the asymptotic normal approximation, which is
# simpler to implement without an extra package and more robust at this
# sample size.

library(dplyr)
library(maps)
source("R/utils_map.R")

set.seed(1)
N_PERMUTATIONS <- 999

## --- Country centroids, same construction as R/12_spatial_error_model.R ---

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

## --- Same OLS model and snapshot as R/03_analysis.R / R/07_figure2.R ------

dataset <- read.csv("data_processed/analysis_dataset.csv")
snapshot_year <- max(dataset$year)
snapshot <- dataset %>%
  filter(year == snapshot_year, !is.na(health_exp_pct_gdp)) %>%
  mutate(map_region = iso3_to_map_region(iso3)) %>%
  inner_join(centroids, by = "map_region")

ols_model <- lm(gap ~ life_expectancy + health_exp_pct_gdp, data = snapshot)
snapshot$residual <- resid(ols_model)

## --- Inverse-squared-distance weights, diagonal zeroed ---------------------

coords <- as.matrix(snapshot[, c("lon", "lat")])
dist_matrix <- as.matrix(dist(coords))
diag(dist_matrix) <- NA  # avoid division by zero on the diagonal
weights <- 1 / (dist_matrix^2)
diag(weights) <- 0

## --- Moran's I -------------------------------------------------------------

morans_i <- function(x, w) {
  n <- length(x)
  xbar <- mean(x)
  dev <- x - xbar
  S0 <- sum(w)
  numerator <- sum(w * outer(dev, dev))
  denominator <- sum(dev^2)
  (n / S0) * (numerator / denominator)
}

observed_i <- morans_i(snapshot$residual, weights)

permuted_i <- vapply(seq_len(N_PERMUTATIONS), function(i) {
  morans_i(sample(snapshot$residual), weights)
}, numeric(1))

## Two-sided permutation p-value: how extreme the observed I is relative to
## the permutation null, in either direction.
p_value <- (sum(abs(permuted_i) >= abs(observed_i)) + 1) / (N_PERMUTATIONS + 1)

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write.csv(
  data.frame(iso3 = snapshot$iso3, region = snapshot$region, residual = snapshot$residual,
             lon = snapshot$lon, lat = snapshot$lat),
  "output/tables/morans_i_residuals.csv", row.names = FALSE
)

sink("output/tables/morans_i_summary.txt")
cat("Moran's I test for spatial autocorrelation in the OLS gap-regression residuals,",
    snapshot_year, "| n countries:", nrow(snapshot), "\n")
cat("NOT attempted by the paper -- this repo's own diagnostic, inverse-squared-\n")
cat("distance weights on crude polygon-vertex centroids (see R/12 and\n")
cat("R/utils_map.R). Permutation-based p-value (", N_PERMUTATIONS, "permutations),\n")
cat("not the asymptotic normal approximation. See README.\n\n")

cat("Observed Moran's I:", round(observed_i, 4), "\n")
cat("Permutation null: mean =", round(mean(permuted_i), 4), ", sd =", round(sd(permuted_i), 4), "\n")
cat("Permutation p-value (two-sided):", signif(p_value, 3), "\n\n")

interpretation <- if (p_value < 0.05 && observed_i > 0) {
  "Significant positive spatial autocorrelation: geographically close countries have more similar OLS residuals than chance would predict. This is the diagnostic that motivates fitting a spatial model at all -- consistent with R/12_spatial_error_model.R finding a real spatial correlation structure and 8 countries flipping classification once it's accounted for."
} else if (p_value < 0.05 && observed_i < 0) {
  "Significant negative spatial autocorrelation: geographically close countries have LESS similar residuals than chance would predict."
} else {
  "No significant spatial autocorrelation detected at the 0.05 level."
}
cat(interpretation, "\n")
sink()

message("Wrote output/tables/morans_i_residuals.csv and morans_i_summary.txt")
message("Moran's I = ", round(observed_i, 4), ", permutation p = ", signif(p_value, 3))
