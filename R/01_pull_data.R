#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Pull WHO GHO Indicator Series (LE, HALE, Health Expenditure)
#------------------------------------------------------------------------------------------


# Pull raw indicator series from the WHO Global Health Observatory OData API.
# Each indicator is cached as an .rds in data_raw/ so re-running the pipeline
# doesn't re-hit the API unless the cache is deleted.

library(jsonlite)

GHO_BASE_URL <- "https://ghoapi.azureedge.net/api/"

## A slow connection can otherwise hit R's default 60s connection timeout
## partway through a pull.
options(timeout = max(120, getOption("timeout")))

## A rate-limited or malformed API response (an HTML error page, an empty
## body, a schema change) would otherwise get cached as-is via saveRDS() and
## silently reused on every subsequent run until data_raw/ is cleared by
## hand. These are the columns every indicator this repo uses actually needs
## (R/02_build_dataset.R); failing loudly here instead of caching garbage is
## cheap insurance.
validate_who_response <- function(df, code) {
  if (!is.data.frame(df) || nrow(df) == 0) {
    stop("WHO GHO API returned no rows for indicator '", code, "' -- not caching. ",
         "Check ", GHO_BASE_URL, code, " directly.")
  }
  required_cols <- c("SpatialDimType", "SpatialDim", "TimeDim", "NumericValue")
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("WHO GHO API response for indicator '", code, "' is missing expected column(s): ",
         paste(missing_cols, collapse = ", "), " -- not caching. The API schema may have changed.")
  }
}

pull_who_indicator <- function(code, cache_dir = "data_raw", refresh = FALSE) {
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  cache_file <- file.path(cache_dir, paste0(code, ".rds"))

  if (file.exists(cache_file) && !refresh) {
    return(readRDS(cache_file))
  }

  df <- fromJSON(paste0(GHO_BASE_URL, code), flatten = TRUE)$value
  validate_who_response(df, code)
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
