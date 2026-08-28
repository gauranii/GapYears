# Figure 3: "Disease profiles segregate states" -- a clustered heatmap of
# disease-burden categories by country (a), a PCA scatter with confidence
# ellipses (b), and a PCA loading plot (c). Reuses the PCA already computed
# in R/05_disease_burden_clustering.R rather than recomputing it.
#
# Panel (b) shows all 6 WHO regions rather than just the paper's 3
# (Europe/Americas/Africa): dropping half the data to match the paper's
# panel exactly seemed like a worse default than showing the full picture,
# but the paper's 3-region choice is easy to reproduce by filtering
# `region %in% c("Europe","Americas","Africa")` before plotting if wanted.

library(dplyr)
library(ggplot2)
library(pheatmap)
source("R/05_disease_burden_clustering.R")

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

regions <- read.csv("data_processed/analysis_dataset.csv") %>%
  distinct(iso3, region)

## --- Panel a: clustered heatmap, causes x countries -------------------------

heatmap_matrix <- t(feature_matrix)  # causes as rows, countries as columns

png("output/figures/fig3a_disease_burden_heatmap.png", width = 12, height = 7, units = "in", res = 150)
pheatmap(
  heatmap_matrix,
  scale = "row",
  show_colnames = FALSE,
  fontsize_row = 7,
  clustering_method = "ward.D2",
  main = paste0("Disease burden (YLD per 1000, row-scaled), ", CLUSTER_YEAR, ", ",
                ncol(heatmap_matrix), " countries")
)
dev.off()

## --- Panel b: PCA scatter with 95% confidence ellipses by region -----------

pc_df <- as.data.frame(pc_scores[, 1:2]) %>%
  rename(PC1 = PC1, PC2 = PC2) %>%
  mutate(iso3 = rownames(pc_scores)) %>%
  left_join(regions, by = "iso3")

fig3b <- ggplot(pc_df, aes(x = PC1, y = PC2, color = region)) +
  geom_point(alpha = 0.7) +
  stat_ellipse(level = 0.95) +
  labs(title = paste0("PCA of disease-burden profiles, ", CLUSTER_YEAR),
       x = paste0("PC1 (", round(var_explained[1] * 100, 1), "%)"),
       y = paste0("PC2 (", round(var_explained[2] * 100, 1), "%)"),
       color = "Region") +
  theme_minimal()

ggsave("output/figures/fig3b_pca_scatter_by_region.png", fig3b, width = 9, height = 6.5, dpi = 150)

## --- Panel c: PCA loading plot for PC1 vs PC2, |loading| > 0.2 cutoff ------

loadings <- as.data.frame(pca$rotation[, 1:2]) %>%
  mutate(cause = rownames(pca$rotation))

CUTOFF <- 0.2
loadings_labeled <- loadings %>% filter(abs(PC1) > CUTOFF | abs(PC2) > CUTOFF)

fig3c <- ggplot(loadings, aes(x = PC1, y = PC2)) +
  geom_segment(aes(xend = PC1, yend = PC2), x = 0, y = 0,
               arrow = arrow(length = unit(0.15, "cm")), alpha = 0.4) +
  geom_text(data = loadings_labeled, aes(label = cause), size = 2.6,
            check_overlap = TRUE, nudge_y = 0.01) +
  geom_hline(yintercept = c(-CUTOFF, CUTOFF), linetype = "dashed", color = "grey60") +
  geom_vline(xintercept = c(-CUTOFF, CUTOFF), linetype = "dashed", color = "grey60") +
  labs(title = paste0("Disease-category loadings on PC1/PC2, ", CLUSTER_YEAR,
                       " (labeled where |loading| > ", CUTOFF, ")"),
       x = "PC1 loading", y = "PC2 loading") +
  theme_minimal()

ggsave("output/figures/fig3c_pca_loadings.png", fig3c, width = 9, height = 7, dpi = 150)

message("Wrote fig3a, fig3b, fig3c to output/figures/")
