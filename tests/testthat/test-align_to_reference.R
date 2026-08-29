## align_to_reference() (R/utils_clustering.R) keeps a consistent cluster-label
## convention across years in R/17_cluster_membership_over_time.R. k-means labels
## are arbitrary per run, so getting this wrong means a country silently looks
## like it "moved clusters" when it didn't, or vice versa -- a wrong-but-plausible
## answer, not a crash, which is exactly what makes it worth pinning down here.

source("../../R/utils_clustering.R")

test_that("identity case: already-agreeing labels are left alone", {
  reference <- data.frame(iso3 = c("AAA", "BBB", "CCC"), cluster = c(1, 1, 2))
  target <- data.frame(iso3 = c("AAA", "BBB", "CCC"), cluster = c(1, 1, 2))

  result <- align_to_reference(target, reference)
  expect_equal(result$cluster, c(1, 1, 2))
})

test_that("swap case: fully-flipped labels get relabeled to match the reference", {
  reference <- data.frame(iso3 = c("AAA", "BBB", "CCC"), cluster = c(1, 1, 2))
  ## target's cluster assignments are the same partition, just labeled the other way
  target <- data.frame(iso3 = c("AAA", "BBB", "CCC"), cluster = c(2, 2, 1))

  result <- align_to_reference(target, reference)
  expect_equal(result$cluster, c(1, 1, 2))
})

test_that("majority-agreement wins when the two years aren't a perfect match", {
  reference <- data.frame(iso3 = c("AAA", "BBB", "CCC", "DDD"), cluster = c(1, 1, 1, 2))
  ## identity already agrees on 3 of 4; swap would only agree on 1 of 4
  target <- data.frame(iso3 = c("AAA", "BBB", "CCC", "DDD"), cluster = c(1, 1, 1, 2))

  result <- align_to_reference(target, reference)
  expect_equal(result$cluster, c(1, 1, 1, 2))
})

test_that("relabeling (when triggered) is applied to every target row, including countries absent from the reference", {
  reference <- data.frame(iso3 = c("AAA", "BBB"), cluster = c(1, 1))
  ## CCC has no counterpart in reference; identity/swap is still decided from AAA/BBB alone
  target <- data.frame(iso3 = c("AAA", "BBB", "CCC"), cluster = c(2, 2, 2))

  result <- align_to_reference(target, reference)
  expect_equal(result$cluster, c(1, 1, 1))
})

test_that("a tie between identity and swap leaves the target unrelabeled (identity wins ties)", {
  ## 1 country agrees under identity (AAA), 1 agrees under swap (BBB): a tie.
  reference <- data.frame(iso3 = c("AAA", "BBB"), cluster = c(1, 1))
  target <- data.frame(iso3 = c("AAA", "BBB"), cluster = c(1, 2))

  result <- align_to_reference(target, reference)
  expect_equal(result$cluster, c(1, 2))  ## unrelabeled: swap must strictly beat identity to trigger
})
