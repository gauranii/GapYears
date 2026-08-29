## morans_i() (R/utils_spatial.R) is a from-scratch base-R implementation (spdep
## isn't available in this environment -- see R/18_morans_i.R). There's no local
## reference implementation to check it against, so these tests lean on a
## hand-derivable identity instead of a black-box expected value.

source("../../R/utils_spatial.R")

test_that("complete graph with equal weights gives the closed-form answer -1/(n-1)", {
  ## For a complete graph (w_ij = 1 for i != j, 0 on the diagonal), S0 = n(n-1),
  ## and sum_i sum_{j!=i} dev_i*dev_j = (sum dev)^2 - sum dev^2 = -sum dev^2
  ## (since deviations from the mean always sum to zero). So the numerator/
  ## denominator ratio is always exactly -1, regardless of x, giving
  ## I = -n/S0 = -1/(n-1). This holds for any non-constant x, so it pins down
  ## the formula's correctness independent of any specific hand-computed value.
  for (n in c(3, 5, 8)) {
    x <- rnorm(n)
    w <- matrix(1, n, n)
    diag(w) <- 0
    expect_equal(morans_i(x, w), -1 / (n - 1), tolerance = 1e-10)
  }
})

test_that("n = 2 complete graph gives I = -1 (a fully hand-checkable case)", {
  x <- c(0, 1)
  w <- matrix(c(0, 1, 1, 0), 2, 2)
  expect_equal(morans_i(x, w), -1, tolerance = 1e-12)
})

test_that("perfectly spatially-clustered data gives I = 1 (its maximum for this weight matrix)", {
  ## Two well-separated groups of identical values, only within-group weights nonzero:
  ## every pair the weights connect agrees perfectly (same sign, same magnitude), which
  ## by hand gives numerator = 1200, denominator = 600, S0 = 12, n = 6 -> I = 1 exactly.
  x <- c(10, 10, 10, -10, -10, -10)
  w <- matrix(0, 6, 6)
  w[1:3, 1:3] <- 1
  w[4:6, 4:6] <- 1
  diag(w) <- 0

  expect_equal(morans_i(x, w), 1, tolerance = 1e-10)
})

test_that("zero weights everywhere is undefined (0/0), not silently zero", {
  x <- c(1, 2, 3)
  w <- matrix(0, 3, 3)
  expect_true(is.nan(morans_i(x, w)))
})
