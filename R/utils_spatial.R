#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Shared Helper - Moran's I for Spatial Autocorrelation
#------------------------------------------------------------------------------------------


# Moran's I, implemented directly in base R: spdep, the standard package for this, pulls
# in sf, which fails to build from source in this environment (the same broken GDAL/
# libtiff/PROJ linkage documented in R/utils_map.R and R/12_spatial_error_model.R). Used
# by R/18_morans_i.R. Pulled out into its own file so the formula itself can be unit-
# tested against a hand-computed example, independent of the WHO data pipeline and the
# `maps` centroid-building code that surrounds it in R/18.
#
# I = (n / S0) * sum_i sum_j w_ij (x_i - xbar)(x_j - xbar) / sum_i (x_i - xbar)^2
# where w_ij are spatial weights and S0 = sum_i sum_j w_ij.

morans_i <- function(x, w) {
  n <- length(x)
  xbar <- mean(x)
  dev <- x - xbar
  S0 <- sum(w)
  numerator <- sum(w * outer(dev, dev))
  denominator <- sum(dev^2)
  (n / S0) * (numerator / denominator)
}
