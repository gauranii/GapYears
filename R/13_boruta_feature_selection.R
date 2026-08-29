#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Boruta Feature Selection on the Disease-Burden Clusters
#------------------------------------------------------------------------------------------


# Boruta feature selection on the disease-burden clusters from
# R/05_disease_burden_clustering.R, the last item the paper's disease-burden
# validation section that this repo had left unattempted (random forest
# validation is R/11; this is the paper's other named check).
#
# CAVEAT, stated here and in the README: this validates this repo's own
# k = 2 clusters, not the paper's k = 3, using Boruta's default settings,
# which the paper does not disclose either. A confirmed/rejected verdict
# here describes which of the 22 disease-burden categories are decisive
# for THIS split, not a reproduction of the paper's own reported features.

library(dplyr)
library(Boruta)

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

## Same near-zero-variance columns 05_disease_burden_clustering.R and
## R/11_cluster_validation_rf.R drop, so the feature set here matches what
## actually produced the clusters being tested.
feature_matrix <- as.matrix(wide[, feature_cols])
zero_var <- apply(feature_matrix, 2, function(x) isTRUE(all.equal(sd(x), 0)))
feature_cols <- feature_cols[!zero_var]

boruta_data <- wide[, c("cluster", feature_cols)]
names(boruta_data) <- make.names(names(boruta_data))

boruta_result <- Boruta(cluster ~ ., data = boruta_data, doTrace = 0)

## Boruta's variable names went through make.names() above (dots for
## spaces); map back to the original, readable cause names so this table
## and the RF/PCA comparison below aren't comparing "Oral.conditions"
## against "Oral conditions" and silently finding zero overlap.
name_lookup <- setNames(feature_cols, make.names(feature_cols))

decision_df <- data.frame(
  cause = unname(name_lookup[names(boruta_result$finalDecision)]),
  decision = as.character(boruta_result$finalDecision),
  median_importance = apply(boruta_result$ImpHistory[, names(boruta_result$finalDecision), drop = FALSE], 2, median, na.rm = TRUE)
) %>%
  arrange(desc(median_importance))

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write.csv(decision_df, "output/tables/cluster_boruta_decisions.csv", row.names = FALSE)

## Cross-check against R/11's random forest importance and the PCA loadings,
## the same two-way comparison R/11 already does, now three-way.
rf_importance <- read.csv("output/tables/cluster_rf_importance.csv")
top10_rf <- head(rf_importance$cause, 10)
top10_boruta <- decision_df %>% filter(decision == "Confirmed") %>% pull(cause) %>% head(10)
overlap_rf_boruta <- intersect(top10_rf, top10_boruta)

sink("output/tables/cluster_boruta_summary.txt")
cat("Boruta feature selection on this repo's own k =", length(levels(boruta_data$cluster)),
    "disease-burden clusters,", CLUSTER_YEAR, "| n countries:", nrow(boruta_data), "\n")
cat("NOT a reproduction of the paper's own feature-selection result -- own\n")
cat("cluster count (k = 2, not the paper's 3), Boruta's default settings. See README.\n\n")

cat("-- Decision counts --\n")
print(table(decision_df$decision))

cat("\n-- Full decisions, ranked by median importance --\n")
print(decision_df)

cat("\n-- Agreement with R/11's random forest top 10 --\n")
cat("Boruta-confirmed (up to 10):", paste(top10_boruta, collapse = ", "), "\n")
cat("RF top 10:", paste(top10_rf, collapse = ", "), "\n")
cat("Overlap:", length(overlap_rf_boruta), "of", length(top10_boruta), "--",
    paste(overlap_rf_boruta, collapse = ", "), "\n")
sink()

message("Wrote output/tables/cluster_boruta_decisions.csv and cluster_boruta_summary.txt")
message("Confirmed: ", sum(decision_df$decision == "Confirmed"),
        " | Tentative: ", sum(decision_df$decision == "Tentative"),
        " | Rejected: ", sum(decision_df$decision == "Rejected"))
