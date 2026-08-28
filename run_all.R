# Run the full v1 pipeline: pull -> build dataset -> analyze.
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
