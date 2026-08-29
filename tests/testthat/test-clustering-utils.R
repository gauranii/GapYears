## R/utils_clustering.R's pca_scores_for_clustering() and select_k_by_silhouette()
## are the shared PCA + k-selection pipeline behind R/05_disease_burden_clustering.R,
## R/16_bootstrap_cluster_k.R, and R/17_cluster_membership_over_time.R. These pin the
## methodology down on synthetic data with a known right answer, independent of
## whatever the live WHO disease-burden numbers happen to be this month.

source("../../R/utils_clustering.R")

test_that("zero-variance columns are dropped before PCA", {
  set.seed(1)
  feature_matrix <- cbind(
    varies_a = rnorm(20),
    varies_b = rnorm(20),
    constant = rep(5, 20)
  )
  rownames(feature_matrix) <- paste0("c", seq_len(20))

  result <- pca_scores_for_clustering(feature_matrix)

  ## 2 real columns -> PCA can have at most 2 components
  expect_lte(ncol(result$pc_scores), 2)
})

test_that("at least 2 components are kept even when 1 component already exceeds the variance threshold", {
  set.seed(1)
  ## One dominant axis plus tiny noise on a second: PC1 alone clears 80% variance,
  ## but the function should still keep >= 2 components.
  base <- rnorm(30)
  feature_matrix <- cbind(a = base, b = base * 2, noise = rnorm(30, sd = 0.001))
  result <- pca_scores_for_clustering(feature_matrix)
  expect_gte(result$n_pc, 2)
})

test_that("select_k_by_silhouette picks k = 2 for two well-separated synthetic clusters", {
  set.seed(42)
  cluster_a <- matrix(rnorm(20, mean = 0, sd = 0.3), ncol = 2)
  cluster_b <- matrix(rnorm(20, mean = 15, sd = 0.3), ncol = 2)
  pc_scores <- rbind(cluster_a, cluster_b)

  result <- select_k_by_silhouette(pc_scores, k_range = 2:5)

  expect_equal(result$best_k, 2)
})

test_that("select_k_by_silhouette picks k = 3 for three well-separated synthetic clusters", {
  set.seed(42)
  cluster_a <- matrix(rnorm(20, mean = 0, sd = 0.3), ncol = 2)
  cluster_b <- matrix(rnorm(20, mean = 15, sd = 0.3), ncol = 2)
  cluster_c <- matrix(rnorm(20, mean = -15, sd = 0.3), ncol = 2)
  pc_scores <- rbind(cluster_a, cluster_b, cluster_c)

  result <- select_k_by_silhouette(pc_scores, k_range = 2:6)

  expect_equal(result$best_k, 3)
})
