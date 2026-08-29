#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : PCA and K-Means Clustering on Disease-Burden Profiles
#------------------------------------------------------------------------------------------


# PCA + k-means on the disease-burden profile per country, mirroring the
# original paper's approach to clustering countries by cause-of-disability
# mix. Uses 2019 rather than the more recent years available: 2020-2021
# carry a distorting "COVID-19 pandemic-related outcomes" cause category
# that the earlier years don't have, and 2019 also matches the paper's own
# analysis window.
#
# Cluster count k is chosen by average silhouette width over k = 2:8,
# rather than asserted, since the paper does not state how it picked k
# either. This is a modeling choice, not a reproduction of a documented
# one -- treat the resulting cluster count and membership as this repo's
# own answer to the question, not the paper's.

library(dplyr)
library(tidyr)

burden <- read.csv("data_processed/disease_burden_long.csv")

CLUSTER_YEAR <- 2019

wide <- burden %>%
  filter(year == CLUSTER_YEAR) %>%
  select(iso3, cause_name, yld_per_1000) %>%
  pivot_wider(names_from = cause_name, values_from = yld_per_1000) %>%
  filter(if_all(-iso3, ~ !is.na(.)))

feature_matrix <- wide %>% select(-iso3) %>% as.matrix()
rownames(feature_matrix) <- wide$iso3

## Drop causes with ~zero variance across countries in this year (e.g. a
## cause category that WHO reports as structurally near-zero everywhere,
## such as "Other COVID-19 pandemic-related outcomes" before the pandemic).
zero_var <- apply(feature_matrix, 2, function(x) isTRUE(all.equal(sd(x), 0)))
if (any(zero_var)) {
  message("Dropping zero-variance cause columns: ", paste(colnames(feature_matrix)[zero_var], collapse = ", "))
  feature_matrix <- feature_matrix[, !zero_var, drop = FALSE]
}

scaled <- scale(feature_matrix)

pca <- prcomp(scaled, center = FALSE, scale. = FALSE)
var_explained <- summary(pca)$importance["Proportion of Variance", ]

## Keep enough components for 80% cumulative variance, at least 2.
n_pc <- max(2, which(cumsum(var_explained) >= 0.80)[1])
pc_scores <- pca$x[, 1:n_pc, drop = FALSE]

silhouette_width <- function(k, x) {
  km <- kmeans(x, centers = k, nstart = 25)
  d <- dist(x)
  sil <- cluster::silhouette(km$cluster, d)
  mean(sil[, "sil_width"])
}

k_range <- 2:8
sil_scores <- vapply(k_range, silhouette_width, numeric(1), x = pc_scores)
best_k <- k_range[which.max(sil_scores)]

set.seed(1)
km_final <- kmeans(pc_scores, centers = best_k, nstart = 25)

cluster_membership <- data.frame(iso3 = wide$iso3, cluster = km_final$cluster)

cluster_profile <- feature_matrix %>%
  as.data.frame() %>%
  mutate(iso3 = rownames(feature_matrix)) %>%
  left_join(cluster_membership, by = "iso3") %>%
  select(-iso3) %>%
  group_by(cluster) %>%
  summarise(across(everything(), mean), n_countries = n(), .groups = "drop")

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write.csv(cluster_membership, "output/tables/disease_burden_clusters.csv", row.names = FALSE)
write.csv(cluster_profile, "output/tables/disease_burden_cluster_profile.csv", row.names = FALSE)
write.csv(
  data.frame(k = k_range, mean_silhouette_width = sil_scores),
  "output/tables/disease_burden_silhouette_by_k.csv", row.names = FALSE
)

sink("output/tables/disease_burden_clustering_summary.txt")
cat("Disease-burden PCA + k-means -- year", CLUSTER_YEAR, "| n countries:", nrow(wide), "\n\n")
cat("-- PCA variance explained (first", n_pc, "PCs, ", round(sum(var_explained[1:n_pc]) * 100, 1), "% cumulative) --\n")
print(round(var_explained[1:n_pc], 3))

cat("\n-- Silhouette width by k --\n")
print(data.frame(k = k_range, mean_silhouette_width = round(sil_scores, 3)))
cat("\nSelected k =", best_k, "(highest mean silhouette width)\n")

cat("\n-- Cluster sizes --\n")
print(table(km_final$cluster))

cat("\n-- Cluster profile: mean YLD per 1000, by cause (top 5 highest-burden causes per cluster) --\n")
for (cl in sort(unique(cluster_membership$cluster))) {
  row <- cluster_profile %>% filter(cluster == cl)
  vals <- row %>% select(-cluster, -n_countries) %>% unlist()
  top5 <- sort(vals, decreasing = TRUE)[1:5]
  cat("\nCluster", cl, "(n =", row$n_countries, "countries):\n")
  print(round(top5, 2))
}
sink()

message("Wrote output/tables/disease_burden_clusters.csv, disease_burden_cluster_profile.csv, ",
        "disease_burden_silhouette_by_k.csv, disease_burden_clustering_summary.txt")
