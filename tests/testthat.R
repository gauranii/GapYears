#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Test Runner Entry Point
#------------------------------------------------------------------------------------------


# Not an R package, so no R CMD check / testthat::test_check() here -- just run
# every test file under tests/testthat/. Must be run with the repo root as the
# working directory (test files source ../../R/*.R relative to their own
# location):
#
#   nix develop --command Rscript tests/testthat.R

library(testthat)

results <- test_dir("tests/testthat", reporter = "summary", stop_on_failure = FALSE)

if (any(as.data.frame(results)$failed > 0)) {
  quit(status = 1)
}
