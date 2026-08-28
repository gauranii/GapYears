# Random forest validation of the disease-burden clusters from
# R/05_disease_burden_clustering.R, mirroring the paper's own use of a
# random forest as a check on cluster separability.
#
# CAVEAT, stated here and in the README: this repo's clustering already
# found k = 2, not the paper's k = 3 (see 05_disease_burden_clustering.R),
# so this validates OUR clusters, not the paper's. The random forest here
# uses this repo's own default hyperparameters (500 trees, default mtry),
# which the paper does not disclose either. Out-of-bag accuracy and
# variable importance below describe how separable this repo's own k = 2
# split is on the same 22 disease-burden features, not a reproduction of
# the paper's reported validation numbers.

library(dplyr)
library(randomForest)

set.seed(1)

burden <- read.csv("data_processed/disease_burden_long.csv")
clusters <- read.csv("output/tables/disease_burden_clusters.csv")

CLUSTER_YEAR <- 2019

wide <- burden %>%
  filter(year == CLUSTER_YEAR) %>%
  select(iso3, cause_name, yld_per_1000) %>%
  tidyr::pivot_wider(names_from = cause_name, values_from = yld_per_1000) %>%
  filter(if_all(-iso3, ~ !is.na(.))) %>%
  inner_join(clusters, by = "iso3") %>%
  mutate(cluster = factor(cluster))

feature_cols <- setdiff(names(wide), c("iso3", "cluster"))

## Drop the same near-zero-variance columns 05_disease_burden_clustering.R
## drops, so the feature set here matches what actually produced the
## clusters being validated.
feature_matrix <- as.matrix(wide[, feature_cols])
zero_var <- apply(feature_matrix, 2, function(x) isTRUE(all.equal(sd(x), 0)))
feature_cols <- feature_cols[!zero_var]

rf_data <- wide[, c("cluster", feature_cols)]
names(rf_data) <- make.names(names(rf_data))  # randomForest needs syntactic names

rf <- randomForest(cluster ~ ., data = rf_data, ntree = 500, importance = TRUE)

importance_df <- as.data.frame(importance(rf)) %>%
  mutate(cause = feature_cols) %>%
  arrange(desc(MeanDecreaseGini)) %>%
  select(cause, MeanDecreaseAccuracy, MeanDecreaseGini)

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write.csv(importance_df, "output/tables/cluster_rf_importance.csv", row.names = FALSE)

## Compare RF's top decisive causes against the PC1/PC2 loadings already
## computed in 05_disease_burden_clustering.R (pca$rotation), as a sanity
## check that the RF and the PCA are pointing at the same underlying
## structure rather than disagreeing about what actually separates the
## clusters.
source("R/05_disease_burden_clustering.R")  # brings `pca` into scope
loadings_abs <- as.data.frame(pca$rotation[, 1:2]) %>%
  mutate(cause = rownames(pca$rotation), abs_pc1 = abs(PC1)) %>%
  select(cause, abs_pc1) %>%
  arrange(desc(abs_pc1))

top10_rf <- head(importance_df$cause, 10)
top10_pca <- head(loadings_abs$cause, 10)
overlap <- intersect(top10_rf, top10_pca)

sink("output/tables/cluster_rf_validation_summary.txt")
cat("Random forest validation of this repo's own k =", length(levels(rf_data$cluster)),
    "disease-burden clusters,", CLUSTER_YEAR, "| n countries:", nrow(rf_data), "\n")
cat("NOT a reproduction of the paper's RF validation -- own hyperparameters,\n")
cat("own cluster count (k = 2, not the paper's 3). See README.\n\n")

cat("-- Confusion matrix (OOB) --\n")
print(rf$confusion)

oob_error <- rf$err.rate[nrow(rf$err.rate), "OOB"]
cat("\nOOB error rate:", round(oob_error, 4), "(OOB accuracy:", round(1 - oob_error, 4), ")\n")

cat("\n-- Variable importance, top 10 by MeanDecreaseGini --\n")
print(head(importance_df, 10))

cat("\n-- Agreement with PCA loadings --\n")
cat("Top 10 RF-important causes:", paste(top10_rf, collapse = ", "), "\n")
cat("Top 10 |PC1 loading| causes:", paste(top10_pca, collapse = ", "), "\n")
cat("Overlap:", length(overlap), "of 10 --", paste(overlap, collapse = ", "), "\n")
sink()

message("Wrote output/tables/cluster_rf_importance.csv and cluster_rf_validation_summary.txt")
message("OOB accuracy: ", round(1 - oob_error, 4), " | RF/PCA top-10 overlap: ", length(overlap), "/10")
