#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : Track Disease-Burden Cluster Membership Over Time
#------------------------------------------------------------------------------------------


# R/05_disease_burden_clustering.R clusters a single year, 2019. This script
# reruns that same pipeline on 2000, 2010, 2015, and 2019 (skipping 2020 and
# 2021, which carry a distorting "Other COVID-19 pandemic-related outcomes"
# category the earlier years don't have, per R/05's own comment), to ask
# whether countries move between the two disease-burden clusters over time,
# not just what the clusters look like in one snapshot.
#
# k is fixed at 2 for every year, this repo's bootstrap-confirmed answer
# (R/16_bootstrap_cluster_k.R, 94% of resamples), rather than re-selected
# per year. Re-selecting k per year would make "did a country change
# cluster" meaningless if the number of clusters itself changed under it.
#
# k-means labels are arbitrary per run: nothing guarantees "cluster 1" in
# 2000 and "cluster 1" in 2019 refer to the same underlying group. To keep
# a single consistent label convention across the whole repo, 2019's
# clustering here is anchored to R/05's already-published
# output/tables/disease_burden_clusters.csv (same data, same preprocessing,
# same seed, so it reproduces identically), and each earlier year is then
# aligned backward to the year after it (2015 to 2019, 2010 to 2015, 2000 to
# 2010) by whichever of the two possible label pairings maximizes overlap
# among the countries present in both years. This is this repo's own
# tracking exercise; the paper does not do this.

library(dplyr)
library(tidyr)
source("R/utils_clustering.R")

TRACK_YEARS <- c(2000, 2010, 2015, 2019)
K <- 2

burden <- read.csv("data_processed/disease_burden_long.csv")
dataset <- read.csv("data_processed/analysis_dataset.csv")
region_lookup <- dataset %>% distinct(iso3, region)

cluster_one_year <- function(target_year) {
  wide <- burden %>%
    filter(year == target_year) %>%
    select(iso3, cause_name, yld_per_1000) %>%
    pivot_wider(names_from = cause_name, values_from = yld_per_1000) %>%
    filter(if_all(-iso3, ~ !is.na(.)))

  feature_matrix <- wide %>% select(-iso3) %>% as.matrix()
  rownames(feature_matrix) <- wide$iso3

  pc_scores <- pca_scores_for_clustering(feature_matrix)$pc_scores

  set.seed(1)
  km <- kmeans(pc_scores, centers = K, nstart = 25)

  data.frame(iso3 = wide$iso3, cluster = km$cluster, year = target_year)
}

results_by_year <- setNames(lapply(TRACK_YEARS, cluster_one_year), as.character(TRACK_YEARS))

## Anchor 2019 to R/05's already-published clustering rather than trusting
## that this script's independent rerun landed on the identical label
## convention by chance (it should, same seed and data, but anchoring
## directly to the file the rest of the repo already references is safer
## than assuming that).
published_2019 <- read.csv("output/tables/disease_burden_clusters.csv")
stopifnot(setequal(results_by_year[["2019"]]$iso3, published_2019$iso3))
results_by_year[["2019"]] <- published_2019 %>% mutate(year = 2019) %>% select(iso3, cluster, year)

## Align each earlier year backward to the year immediately after it, by
## whichever of the two label pairings (identity or swap) maximizes
## agreement among countries present in both years. align_to_reference()
## itself lives in R/utils_clustering.R, where it's unit-tested directly.

years_desc <- sort(TRACK_YEARS, decreasing = TRUE)
for (i in seq_len(length(years_desc) - 1)) {
  ref_year <- as.character(years_desc[i])
  tgt_year <- as.character(years_desc[i + 1])
  results_by_year[[tgt_year]] <- align_to_reference(results_by_year[[tgt_year]], results_by_year[[ref_year]])
}

all_years <- bind_rows(results_by_year) %>%
  left_join(region_lookup, by = "iso3")

wide_membership <- all_years %>%
  select(iso3, region, year, cluster) %>%
  pivot_wider(names_from = year, values_from = cluster, names_prefix = "cluster_")

## A country "moved" if its aligned cluster differs between its earliest and
## latest available year in this 4-year set.
year_cols <- paste0("cluster_", TRACK_YEARS)
present_year_cols <- intersect(year_cols, names(wide_membership))

movement <- wide_membership %>%
  rowwise() %>%
  mutate(
    n_years_observed = sum(!is.na(c_across(all_of(present_year_cols)))),
    first_cluster = c_across(all_of(present_year_cols))[which(!is.na(c_across(all_of(present_year_cols))))[1]],
    last_cluster = rev(c_across(all_of(present_year_cols))[which(!is.na(c_across(all_of(present_year_cols))))])[1],
    moved = n_years_observed >= 2 && first_cluster != last_cluster
  ) %>%
  ungroup()

movers <- movement %>% filter(moved) %>% arrange(region, iso3)

## Pairwise consecutive-year transition counts (e.g. 2000->2010, 2010->2015,
## 2015->2019), each restricted to countries present in both years of the
## pair.
pairwise_transitions <- lapply(seq_len(length(TRACK_YEARS) - 1), function(i) {
  y1 <- TRACK_YEARS[i]
  y2 <- TRACK_YEARS[i + 1]
  d1 <- results_by_year[[as.character(y1)]] %>% select(iso3, cluster)
  d2 <- results_by_year[[as.character(y2)]] %>% select(iso3, cluster)
  joined <- inner_join(d1, d2, by = "iso3", suffix = c("_from", "_to"))
  data.frame(
    from_year = y1, to_year = y2,
    n_common_countries = nrow(joined),
    n_changed = sum(joined$cluster_from != joined$cluster_to)
  )
}) %>% bind_rows()

movers_by_region <- movers %>% count(region, name = "n_movers") %>% arrange(desc(n_movers))

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write.csv(wide_membership, "output/tables/cluster_membership_by_year.csv", row.names = FALSE)
write.csv(movers %>% select(iso3, region, first_cluster, last_cluster, all_of(present_year_cols)),
          "output/tables/cluster_membership_movers.csv", row.names = FALSE)
write.csv(pairwise_transitions, "output/tables/cluster_membership_transitions.csv", row.names = FALSE)

sink("output/tables/cluster_membership_over_time_summary.txt")
cat("Disease-burden cluster membership over time,", paste(TRACK_YEARS, collapse = ", "),
    "| k =", K, "(fixed, this repo's bootstrap-confirmed answer)\n")
cat("NOT attempted by the paper -- this repo's own tracking exercise, cluster\n")
cat("labels aligned across years by maximum overlap, anchored to R/05's\n")
cat("published 2019 clustering. See README.\n\n")

cat("-- Consecutive-year transitions --\n")
print(pairwise_transitions)

cat("\n-- Countries whose aligned cluster differs between their first and last observed year --\n")
cat(nrow(movers), "of", nrow(movement), "countries with at least 2 observed years moved clusters.\n\n")
print(movers %>% select(iso3, region, first_cluster, last_cluster))

cat("\n-- Movers by region --\n")
print(movers_by_region)
sink()

message("Wrote output/tables/cluster_membership_by_year.csv, cluster_membership_movers.csv, ",
        "cluster_membership_transitions.csv, cluster_membership_over_time_summary.txt")
message(nrow(movers), " countries moved clusters between their first and last observed year")
