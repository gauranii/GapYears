#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Pull WHO GHE Cause-Specific Disease-Burden (YLD) Data
#------------------------------------------------------------------------------------------


# Pull country-level, cause-specific years-lived-with-disability (YLD) data
# from WHO's Global Health Estimates (GHE) bulk XLSX files -- a different
# system from the simple GHO OData API used in 01_pull_data.R, and the
# dependency that blocked the paper's disease-burden clustering in v1.
#
# Source: https://www.who.int/data/gho/data/themes/mortality-and-global-health-estimates/global-health-estimates-leading-causes-of-dalys
# These are the WHO GHE2021 round's "results tool" bulk exports (the GUI
# results tool itself has no discoverable JSON API; these XLSX files are
# the same underlying data as a direct download).
#
# File layout (sheet "All ages"): rows are causes of disability, arranged in
# a five-level outline (I./A./1./a./i.), repeated once each for Persons,
# Males, Females. Columns 8 onward are one country each, with country name
# in row 7 and ISO-3 code in row 8. A row's cause name is whichever of
# columns 3-7 is non-NA; the outline depth is that column's index minus 2.
# Values are in thousands, same unit as the Population('000) row, so
# value / population gives a population-comparable rate.

library(dplyr)
library(readxl)

GHE_YEARS <- c(2000, 2010, 2015, 2019, 2020, 2021)
GHE_XLSX_DIR <- "data_raw/ghe_xlsx"

ghe_xlsx_url <- function(year) {
  sprintf(
    "https://cdn.who.int/media/docs/default-source/gho-documents/global-health-estimates/ghe2021_yld_bycountry_%d.xlsx",
    year
  )
}

download_ghe_yld <- function(year, refresh = FALSE) {
  dir.create(GHE_XLSX_DIR, showWarnings = FALSE, recursive = TRUE)
  dest <- file.path(GHE_XLSX_DIR, sprintf("ghe2021_yld_bycountry_%d.xlsx", year))
  if (!file.exists(dest) || refresh) {
    download.file(ghe_xlsx_url(year), dest, mode = "wb", quiet = TRUE)
  }
  dest
}

## Extract Level-2 cause categories (the ~29 "A./B./C." categories nested
## directly under the three top-level I/II/III groups) for the "Persons"
## (both-sexes) block, as a rate per 1000 population.
parse_ghe_yld <- function(path, year) {
  raw <- suppressMessages(read_excel(path, sheet = "All ages", col_names = FALSE))

  header_hit <- which(apply(raw, 1, function(r) any(grepl("Country or area", r, fixed = TRUE))))[1]
  iso3_row <- header_hit + 1
  country_cols <- 8:ncol(raw)
  iso3 <- unlist(raw[iso3_row, country_cols], use.names = FALSE)

  persons <- raw[raw[[1]] == "Persons" & !is.na(raw[[1]]), ]

  ## Outline depth: rightmost non-NA column among 3:7, minus 2.
  name_col <- apply(persons[, 3:7], 1, function(r) {
    idx <- which(!is.na(r))
    if (length(idx) == 0) NA_integer_ else max(idx) + 2
  })
  depth <- name_col - 2L

  pop_row <- which(grepl("^Population", persons[[4]]) & !is.na(persons[[4]]))
  population <- as.numeric(unlist(persons[pop_row, country_cols], use.names = FALSE))

  ## depth 2 catches "All Causes", "Population", and the 3 top-level I/II/III
  ## groups (each has only its own name column populated, same as this
  ## formula gives depth-2 categories -- verified against a manual read of
  ## the outline). The ~24 "A./B./C." categories one level below those are
  ## depth 3.
  level2 <- persons[!is.na(depth) & depth == 3, ]
  level2_name_col <- name_col[!is.na(depth) & depth == 3]

  cause_name <- vapply(seq_len(nrow(level2)), function(i) {
    as.character(level2[[level2_name_col[i]]][i])
  }, character(1))
  cause_code <- as.numeric(level2[[2]])

  values <- as.matrix(level2[, country_cols])
  storage.mode(values) <- "double"

  rate_per_1000 <- sweep(values, 2, population, "/") * 1000

  colnames(rate_per_1000) <- iso3
  rownames(rate_per_1000) <- cause_name

  as.data.frame(rate_per_1000) %>%
    mutate(cause_code = cause_code, cause_name = cause_name, .before = 1) %>%
    tidyr::pivot_longer(-c(cause_code, cause_name), names_to = "iso3", values_to = "yld_per_1000") %>%
    mutate(year = year) %>%
    filter(!is.na(yld_per_1000))
}

if (sys.nframe() == 0) {
  burden_long <- lapply(GHE_YEARS, function(y) {
    path <- download_ghe_yld(y)
    parse_ghe_yld(path, y)
  }) %>% bind_rows()

  dir.create("data_processed", showWarnings = FALSE)
  write.csv(burden_long, "data_processed/disease_burden_long.csv", row.names = FALSE)
  message(
    "Wrote ", nrow(burden_long), " rows: ", length(GHE_YEARS), " years x ",
    length(unique(burden_long$cause_name)), " cause categories x up to ",
    length(unique(burden_long$iso3)), " countries"
  )
}
