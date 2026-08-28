# Pull raw indicator series from the WHO Global Health Observatory OData API.
# Each indicator is cached as an .rds in data_raw/ so re-running the pipeline
# doesn't re-hit the API unless the cache is deleted.

library(jsonlite)

GHO_BASE_URL <- "https://ghoapi.azureedge.net/api/"

pull_who_indicator <- function(code, cache_dir = "data_raw", refresh = FALSE) {
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  cache_file <- file.path(cache_dir, paste0(code, ".rds"))

  if (file.exists(cache_file) && !refresh) {
    return(readRDS(cache_file))
  }

  df <- fromJSON(paste0(GHO_BASE_URL, code), flatten = TRUE)$value
  saveRDS(df, cache_file)
  df
}

indicators <- c(
  life_expectancy      = "WHOSIS_000001",
  healthy_life_expectancy = "WHOSIS_000002",
  health_exp_pct_gdp   = "GHED_CHEGDP_SHA2011"
)

if (sys.nframe() == 0) {
  raw <- lapply(indicators, pull_who_indicator)
  message("Pulled ", paste(names(raw), "(", vapply(raw, nrow, integer(1)), "rows)", collapse = ", "))
}
