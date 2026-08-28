# Run the full pipeline: pull -> build dataset -> analyze -> disease burden.
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
