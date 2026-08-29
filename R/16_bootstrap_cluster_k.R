#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Bootstrap the k = 2 vs. k = 3 Disease-Burden Cluster Count
#------------------------------------------------------------------------------------------


# R/05_disease_burden_clustering.R picks k = 2 by silhouette width on the
# single, actual sample of 185 countries, not the paper's reported k = 3.
# That is one number from one sample. This script asks how much that answer
# would wobble under resampling: draw many bootstrap samples of countries
# (with replacement, the standard bootstrap), rerun the same PCA + k-means +
# silhouette pipeline on each, and tabulate how often each k actually wins.
#
# This is this repo's own robustness check, not something the paper does or
# reports doing. A bootstrap sample containing duplicate countries is
# expected and is not a bug -- it is what "resample with replacement" means,
# and it is the standard way to assess how stable a clustering answer is.

library(dplyr)
library(tidyr)
library(cluster)
source("R/utils_clustering.R")

burden <- read.csv("data_processed/disease_burden_long.csv")

CLUSTER_YEAR <- 2019
K_RANGE <- 2:8
N_BOOT <- 200

set.seed(1)

wide <- burden %>%
  filter(year == CLUSTER_YEAR) %>%
  select(iso3, cause_name, yld_per_1000) %>%
  pivot_wider(names_from = cause_name, values_from = yld_per_1000) %>%
  filter(if_all(-iso3, ~ !is.na(.)))

feature_matrix_full <- wide %>% select(-iso3) %>% as.matrix()
rownames(feature_matrix_full) <- wide$iso3
n_countries <- nrow(feature_matrix_full)

## Same pipeline as R/05_disease_burden_clustering.R (R/utils_clustering.R), as a
## function of an arbitrary feature matrix, so it can be rerun identically on each
## bootstrap resample.
best_k_for <- function(feature_matrix) {
  pc_scores <- pca_scores_for_clustering(feature_matrix)$pc_scores
  select_k_by_silhouette(pc_scores, k_range = K_RANGE)$best_k
}

## The observed answer, on the actual sample (should match R/05's best_k).
observed_k <- best_k_for(feature_matrix_full)

## The bootstrap: resample countries with replacement, N_BOOT times.
boot_k <- vapply(seq_len(N_BOOT), function(i) {
  boot_rows <- sample(seq_len(n_countries), n_countries, replace = TRUE)
  best_k_for(feature_matrix_full[boot_rows, , drop = FALSE])
}, integer(1))

k_table <- table(factor(boot_k, levels = K_RANGE))
k_props <- prop.table(k_table)

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write.csv(
  data.frame(k = K_RANGE, n_bootstrap_wins = as.integer(k_table), proportion = as.numeric(k_props)),
  "output/tables/cluster_k_bootstrap.csv", row.names = FALSE
)

sink("output/tables/cluster_k_bootstrap_summary.txt")
cat("Bootstrap on the disease-burden cluster count k,", CLUSTER_YEAR,
    "| n countries:", n_countries, "| n bootstrap replicates:", N_BOOT, "\n")
cat("NOT attempted by the paper -- this repo's own robustness check on its\n")
cat("own k = 2 (vs. the paper's reported k = 3) answer from R/05. See README.\n\n")

cat("-- Observed k on the actual sample --\n")
cat("k =", observed_k, "\n\n")

cat("-- How often each k wins the silhouette test across", N_BOOT, "bootstrap resamples --\n")
print(data.frame(k = K_RANGE, wins = as.integer(k_table), proportion = round(as.numeric(k_props), 3)))

top_k <- K_RANGE[which.max(k_table)]
cat("\nModal bootstrap k =", top_k, "(", round(max(k_props) * 100, 1), "% of resamples )\n")
sink()

message("Wrote output/tables/cluster_k_bootstrap.csv and cluster_k_bootstrap_summary.txt")
message("Observed k = ", observed_k, " | modal bootstrap k = ", top_k,
        " (", round(max(k_props) * 100, 1), "% of ", N_BOOT, " resamples)")
