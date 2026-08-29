#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Figure 4 - PCA + K-Means Clustering Figure Panels
#------------------------------------------------------------------------------------------


# Figure 4: "AI clusters disease burden patterns" -- PCA+k-means scatter (a),
# regional composition per cluster as a stacked bar (b) and donuts (c), and
# the healthspan-lifespan gap by cluster as a violin (d) and by
# cluster-within-region as a boxplot (e).
#
# Uses this repo's own k = 2 clustering result (see R/05 and the README),
# not the paper's reported 3 clusters -- the panel layout mirrors the
# paper's, the cluster count does not, by design.

library(dplyr)
library(ggplot2)
source("R/05_disease_burden_clustering.R")

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

analysis <- read.csv("data_processed/analysis_dataset.csv")
snapshot_year <- max(analysis$year)
regions <- analysis %>% distinct(iso3, region)

cluster_df <- cluster_membership %>%
  mutate(cluster = factor(cluster)) %>%
  left_join(regions, by = "iso3")

## --- Panel a: PCA scatter colored by cluster, with confidence ellipses ----

pc_df <- as.data.frame(pc_scores[, 1:2]) %>%
  mutate(iso3 = rownames(pc_scores)) %>%
  left_join(cluster_df, by = "iso3")

fig4a <- ggplot(pc_df, aes(x = PC1, y = PC2, color = cluster)) +
  geom_point(alpha = 0.7) +
  stat_ellipse(level = 0.95) +
  labs(title = paste0("Disease-burden clusters (k = ", best_k, "), ", CLUSTER_YEAR),
       x = "PC1", y = "PC2", color = "Cluster") +
  theme_minimal()

ggsave("output/figures/fig4a_cluster_pca_scatter.png", fig4a, width = 8, height = 6.5, dpi = 150)

## --- Panel b: stacked bar of regional composition per cluster -------------

comp <- cluster_df %>% count(cluster, region) %>% group_by(cluster) %>% mutate(share = n / sum(n)) %>% ungroup()

fig4b <- ggplot(comp, aes(x = cluster, y = share, fill = region)) +
  geom_col() +
  labs(title = "Regional composition of each disease-burden cluster",
       x = "Cluster", y = "Share of countries", fill = "Region") +
  theme_minimal()

ggsave("output/figures/fig4b_cluster_regional_stackedbar.png", fig4b, width = 7, height = 6, dpi = 150)

## --- Panel c: donut of regional breakdown per cluster ----------------------

fig4c <- ggplot(comp, aes(x = 2, y = share, fill = region)) +
  geom_col(color = "white") +
  coord_polar(theta = "y") +
  xlim(0.5, 2.5) +
  facet_wrap(~cluster, labeller = label_both) +
  labs(title = "Regional breakdown within each cluster", fill = "Region", x = NULL, y = NULL) +
  theme_void()

ggsave("output/figures/fig4c_cluster_regional_donut.png", fig4c, width = 9, height = 5.5, dpi = 150)

## --- Panel d: violin of gap by cluster -------------------------------------

gap_by_cluster <- analysis %>%
  filter(year == snapshot_year) %>%
  inner_join(cluster_df %>% select(iso3, cluster), by = "iso3")

fig4d <- ggplot(gap_by_cluster, aes(x = cluster, y = gap, fill = cluster)) +
  geom_violin(alpha = 0.6) +
  geom_boxplot(width = 0.1, outlier.shape = NA) +
  labs(title = paste0("Healthspan-lifespan gap by disease-burden cluster, ", snapshot_year),
       x = "Cluster", y = "Gap (years)") +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("output/figures/fig4d_gap_by_cluster_violin.png", fig4d, width = 7, height = 6, dpi = 150)

## --- Panel e: boxplot of gap by cluster, faceted by region -----------------

fig4e <- ggplot(gap_by_cluster, aes(x = cluster, y = gap, fill = cluster)) +
  geom_boxplot(outlier.size = 0.8) +
  facet_wrap(~region) +
  labs(title = paste0("Gap by cluster within region, ", snapshot_year),
       x = "Cluster", y = "Gap (years)") +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("output/figures/fig4e_gap_by_cluster_within_region.png", fig4e, width = 10, height = 7, dpi = 150)

message("Wrote fig4a-fig4e to output/figures/")
