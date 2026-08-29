#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Shared Helpers - PCA/K-Means Cluster-Count Selection and Cross-Year Label Alignment
#------------------------------------------------------------------------------------------


# Shared PCA + k-means-by-silhouette pipeline, used by R/05_disease_burden_clustering.R
# (single-year clustering) and R/16_bootstrap_cluster_k.R (the identical pipeline rerun
# on bootstrap resamples of the same countries). Pulled out here so both scripts run the
# same logic instead of two hand-copies that could silently drift apart.

library(cluster)

## Zero-variance columns dropped, scaled, PCA'd, enough components kept for >= min_cumvar
## cumulative variance (at least 2 components regardless). Returns the PC score matrix
## k-means clusters on downstream, plus the zero-variance-column-reduced feature_matrix
## and the prcomp() object itself, both of which R/08_figure3.R and
## R/11_cluster_validation_rf.R read directly back out of R/05's global environment
## after sourcing it (heatmap input and `pca$rotation`, respectively) -- callers should
## reassign their own feature_matrix/pca from this result rather than keeping the
## pre-PCA versions around.
pca_scores_for_clustering <- function(feature_matrix, min_cumvar = 0.80) {
  zero_var <- apply(feature_matrix, 2, function(x) isTRUE(all.equal(sd(x), 0)))
  if (any(zero_var)) feature_matrix <- feature_matrix[, !zero_var, drop = FALSE]

  scaled <- scale(feature_matrix)
  pca <- prcomp(scaled, center = FALSE, scale. = FALSE)
  var_explained <- summary(pca)$importance["Proportion of Variance", ]
  n_pc <- max(2, which(cumsum(var_explained) >= min_cumvar)[1])

  list(
    pc_scores = pca$x[, 1:n_pc, drop = FALSE],
    var_explained = var_explained,
    n_pc = n_pc,
    pca = pca,
    feature_matrix = feature_matrix
  )
}

## k chosen by mean silhouette width over k_range, on a PC-score matrix.
select_k_by_silhouette <- function(pc_scores, k_range = 2:8) {
  d <- dist(pc_scores)
  sil_scores <- vapply(k_range, function(k) {
    km <- kmeans(pc_scores, centers = k, nstart = 25)
    mean(silhouette(km$cluster, d)[, "sil_width"])
  }, numeric(1))
  list(best_k = k_range[which.max(sil_scores)], sil_scores = sil_scores, k_range = k_range)
}

## k-means labels are arbitrary from one run to the next. Given a two-cluster `target`
## data frame (columns iso3, cluster) and a `reference` data frame in the same shape,
## relabel `target`'s clusters (the 3 - x swap, since k = 2) if that maximizes agreement
## with `reference` on the countries present in both. Used by
## R/17_cluster_membership_over_time.R to keep a single consistent label convention
## across years, since k-means run independently per year has no reason to agree on
## which cluster is "1" and which is "2".
align_to_reference <- function(target, reference) {
  common <- dplyr::inner_join(target, reference, by = "iso3", suffix = c("_target", "_ref"))
  agree_identity <- sum(common$cluster_target == common$cluster_ref)
  agree_swap <- sum((3 - common$cluster_target) == common$cluster_ref)  # k = 2, so swap is 3 - x
  if (agree_swap > agree_identity) {
    target$cluster <- 3 - target$cluster
  }
  target
}
