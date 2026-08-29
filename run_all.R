#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Run the Full Pipeline End to End
#------------------------------------------------------------------------------------------


# Run the full pipeline: pull -> build dataset -> analyze -> disease burden -> figures.
# Usage: Rscript run_all.R

source("R/02_build_dataset.R")
dataset <- build_dataset()
dir.create("data_processed", showWarnings = FALSE)
write.csv(dataset, "data_processed/analysis_dataset.csv", row.names = FALSE)
message(
  "Wrote ", nrow(dataset), " country-year rows spanning ",
  min(dataset$year), "-", max(dataset$year)
)

source("R/03_analysis.R")

source("R/04_pull_disease_burden.R")
burden_long <- dplyr::bind_rows(lapply(GHE_YEARS, function(y) parse_ghe_yld(download_ghe_yld(y), y)))
write.csv(burden_long, "data_processed/disease_burden_long.csv", row.names = FALSE)
message("Wrote ", nrow(burden_long), " disease-burden rows")

source("R/05_disease_burden_clustering.R")

source("R/06_figure1.R")
source("R/07_figure2.R")
source("R/08_figure3.R")
source("R/09_figure4.R")
source("R/10_figure5.R")

source("R/11_cluster_validation_rf.R")
source("R/12_spatial_error_model.R")
source("R/13_boruta_feature_selection.R")
source("R/14_panel_regression.R")
source("R/15_quantile_regression.R")
source("R/16_bootstrap_cluster_k.R")
source("R/17_cluster_membership_over_time.R")
source("R/18_morans_i.R")
source("R/19_lasso_gap_predictors.R")
