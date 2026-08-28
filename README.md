# GapYears

A partial replication, and 2021 extension, of ["Global variation in the gap between lifespan and healthspan"](https://www.nature.com/articles/s43856-025-01111-2) (*Communications Medicine*, 2025), which measures how many years people live in poor health at the end of life, and how that gap varies by world region.

The paper's data is public. Its code is not, so this is a from-scratch reconstruction from the methods text, not a verified match against a reference implementation. Where the original methodology can't be reproduced cleanly from public data, that's stated below rather than forced.

## What this replicates

- The core metric: healthspan-lifespan gap = life expectancy (LE) − healthy life expectancy (HALE)
- Regional variation in the gap, tested with Kruskal-Wallis and BH-adjusted pairwise comparisons
- A forward-selection linear regression on gap predictors
- A disease-burden PCA + k-means clustering of countries (phase 2 — see below), using real cause-specific YLD data, not attempted in v1
- All 5 of the paper's main-text figures, redrawn from this repo's own numbers (see Figures below) — panel-for-panel where the underlying method is reproducible, clearly-labeled substitutes where it isn't

## What this does not attempt, and why

| Original component | Status | Reason |
|---|---|---|
| Random forest validation / Boruta feature selection on the disease-burden clusters | Not attempted | The phase-2 pull solved the data-access problem, but validating the clustering this way is still open |
| Spatial error model | Not attempted | The paper doesn't specify the geographic adjacency/weights structure it used; any reconstruction would be a guess, not a replication |
| Projection to 2100 (paper's "22% widening" claim) | Substituted, not replicated | The paper's forecasting method isn't disclosed. Figure 5b is this repo's own naive linear extrapolation of each region's mean-gap trend, labeled as such in the plot itself — an illustration of what a straight line implies, not a reproduction of their number |
| UN World Population Prospects demographics | Not yet incorporated | The pipeline uses only WHO indicators (LE, HALE, health expenditure, disease burden) |

## Phase 2: disease-burden clustering

v1 could not attempt the paper's PCA/k-means/Boruta/random-forest section because WHO's simple bulk OData API only exposes years-lived-with-disability (YLD) as global/regional aggregates through 2012 — useless for country-level clustering. The actual country-level, cause-specific data turned out to be reachable after all, just not through that API.

**Source found:** WHO's Global Health Estimates (GHE) 2021 round publishes direct bulk XLSX downloads, one file per year, at predictable URLs under `cdn.who.int/media/docs/default-source/gho-documents/global-health-estimates/ghe2021_yld_bycountry_<year>.xlsx` (linked from the [leading-causes-of-DALYs page](https://www.who.int/data/gho/data/themes/mortality-and-global-health-estimates/global-health-estimates-leading-causes-of-dalys), no API or auth needed). The GHE Results Tool itself is a click-through UI with no discoverable JSON backend; these bulk files are the same underlying data without needing to script the UI.

**What `R/04_pull_disease_burden.R` does:** downloads the YLD file for 2000, 2010, 2015, 2019, 2020, and 2021, and parses the "All ages" sheet — a five-level outline of disability causes (WHO's own numbering, columns 3-7 hold that outline's markers and names depending on depth) by country. It keeps the ~24 mid-level cause categories (Communicable diseases, Cardiovascular diseases, Mental and substance use disorders, and so on — the same resolution a burden-of-disease clustering study would typically use, not the full ~130-row leaf-level list), for the combined-sex "Persons" rows, expressed as YLD per 1000 population.

**What `R/05_disease_burden_clustering.R` does:** standardizes the 2019 cross-section (chosen over 2020-2021 to avoid the COVID-outcomes category that only exists in later years, and because 2019 matches the paper's own window), runs PCA, keeps enough components for 80% cumulative variance, and runs k-means with k chosen by mean silhouette width over k = 2 to 8 — a modeling choice, not a reproduction of one the paper documents, since the paper doesn't state how it picked its cluster count either.

**Result:** k = 2 was the silhouette-preferred split (78 vs. 107 countries), not the paper's reported 3 clusters — a real methodological difference worth sitting with, not something to force into agreement. Cluster 1 (USA, GBR, JPN, DEU, BRA, CHN among others) carries a higher relative burden from musculoskeletal disease and mental/substance-use disorders; cluster 2 (AFG, ETH, IND, NGA among others) carries relatively more infectious-disease burden alongside still-substantial mental and musculoskeletal burden. That split reads like the familiar income/age-structure divide in global disease burden, which is a sensible result, but it is this repo's own answer to "how many clusters," not a check against the paper's.

Full output in `output/tables/disease_burden_clusters.csv` (per-country membership), `disease_burden_cluster_profile.csv` (per-cluster means), and `disease_burden_silhouette_by_k.csv`.

**Still open:** validating the clustering with a random forest and Boruta, the way the paper does, and checking whether a different k or a different clustering method (GMM, hierarchical) changes the story.

## Figures

All 15 panels are in `output/figures/`, one PNG per panel rather than composited multi-panel figures. Each is generated by one of `R/06_figure1.R` through `R/10_figure5.R`.

| Figure | Panel | What it shows | Deviation from the paper |
|---|---|---|---|
| 1 | a | Density of lifespan (LE) vs. healthspan (HALE), by region | 2021 snapshot, not 2019 |
| 1 | b | World choropleth of the gap per country | Map drawn with the `maps`/`mapdata` packages, not `sf`/Natural Earth — the latter's `terra` dependency failed to build from source in this environment (missing libtiff/PROJ linkage). `maps`' country polygons use older/different names than ISO3 codes; 16 of 185 were hand-matched in `R/utils_map.R` (documented there), and Antigua & Barbuda / Trinidad & Tobago each show only their larger island |
| 1 | c | Boxplot of the gap by region, points overlaid | 2021 snapshot |
| 2 | a, b | Maps of countries with a larger/smaller-than-predicted gap | "Predicted" comes from this repo's own regression (`gap ~ life_expectancy + health_exp_pct_gdp`), which omits the paper's third predictor, NCD burden — so the exact set of over/under-predicted countries won't match theirs, even though the method (residuals from a fitted model) is the same idea |
| 2 | c | Regional composition donut for each deviation group | Same caveat as above |
| 3 | a | Clustered heatmap, 22 disease categories × 185 countries | Row-scaled YLD per 1000, Ward's method clustering on both axes |
| 3 | b | PCA scatter of countries with 95% confidence ellipses | Shows all 6 WHO regions; the paper's panel highlights only Europe/Americas/Africa. Filter to those 3 before plotting to match its panel exactly |
| 3 | c | PCA loading plot, causes labeled where \|loading\| > 0.2 | — |
| 4 | a | PCA + k-means scatter with confidence ellipses | k = 2 (this repo's silhouette-chosen result), not the paper's k = 3 — see Phase 2 above |
| 4 | b, c | Regional composition per cluster, stacked bar and donut | Reflects the k = 2 split |
| 4 | d | Violin of the gap by cluster | Reflects the k = 2 split |
| 4 | e | Boxplot of the gap by cluster, faceted by region | Reflects the k = 2 split |
| 5 | a | Boxplot of each country's linear gap trend, 2000-2021, by region | — |
| 5 | b | Projected regional gap trend to 2100 | This repo's own naive linear extrapolation (per-region `lm(gap ~ year)`, extended to 2100 with a confidence ribbon) — the paper does not disclose its projection method, so this is a clearly-labeled substitute, not a reproduction of their "22% widening" figure |

## Data sources

All pulled from the [WHO Global Health Observatory OData API](https://www.who.int/data/gho/info/gho-odata-api) (`https://ghoapi.azureedge.net/api/`), no authentication required:

| Indicator | Code | Coverage found |
|---|---|---|
| Life expectancy at birth | `WHOSIS_000001` | 2000-2021, country-level, by sex |
| Healthy life expectancy (HALE) at birth | `WHOSIS_000002` | 2000-2021, country-level, by sex |
| Current health expenditure (% of GDP) | `GHED_CHEGDP_SHA2011` | 2000-2023, country-level |

The paper's window was 2000-2019; both LE and HALE are available through 2021 as of this pull, so this repo reports on the 2021 snapshot rather than re-deriving 2019. Note that WHO and UN periodically revise *historical* estimates retroactively, so even the shared 2000-2019 years are not guaranteed to numerically match the paper's original pull.

## Results (2021 snapshot, this repo)

Regional median gap, ordered narrowest to widest (full table in `output/tables/regional_summary.csv`):

| Region | Countries | Median gap (years) |
|---|---|---|
| Africa | 47 | 8.22 |
| Western Pacific | 22 | 8.57 |
| South-East Asia | 10 | 9.35 |
| Americas | 34 | 9.56 |
| Europe | 50 | 10.06 |
| Eastern Mediterranean | 22 | 10.22 |

Kruskal-Wallis test for regional differences: χ² = 71.09, df = 5, p < 1e-13. Regions differ; the BH-adjusted pairwise comparisons in `output/tables/analysis_summary.txt` show which pairs.

Forward-selection regression retained both candidate predictors:

```
gap = -2.22 + 0.158 × life_expectancy + 0.053 × health_exp_pct_gdp
Adjusted R² = 0.819, both coefficients p < 0.001
```

Africa having the narrowest gap, and life expectancy plus health spending both predicting gap size, both line up directionally with the original paper. The exact gap values differ, which is expected given the different snapshot year and WHO's retroactive data revisions, not a discrepancy this repo tries to resolve away.

## Reproducing this

Needs R plus `jsonlite`, `dplyr`, `tidyr`, `readxl`, `cluster`, `ggplot2`, `maps`, `mapdata`, `countrycode`, `pheatmap`, and `MASS`. If you don't have R installed:

```
nix-shell -p R rPackages.jsonlite rPackages.dplyr rPackages.tidyr rPackages.readxl rPackages.cluster rPackages.ggplot2 rPackages.maps rPackages.mapdata rPackages.countrycode rPackages.pheatmap rPackages.MASS --run "Rscript run_all.R"
```

Otherwise, from an R session with those packages installed:

```r
source("run_all.R")
```

This pulls fresh data from the WHO API and the GHE bulk files (cached in `data_raw/`, gitignored — the GHE xlsx files alone run ~12MB x 6 years), builds `data_processed/analysis_dataset.csv` and `disease_burden_long.csv`, writes results to `output/tables/`, and writes all 15 figure panels to `output/figures/`.

## Roadmap

- Incorporate UN WPP demographics
- Validate the disease-burden clusters with a random forest / Boruta pass, as the paper does
- Compare k-means against an alternative (GMM, hierarchical) and the silhouette-chosen k against other selection criteria, as a check on how sensitive the clustering is to those choices
- Revisit the world map if `sf`/Natural Earth becomes buildable in this environment, for finer polygon detail than `maps` provides
