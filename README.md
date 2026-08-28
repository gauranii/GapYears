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
| Random forest validation of the disease-burden clusters | Attempted, own hyperparameters | See "Validation and robustness checks" below. Boruta feature selection specifically is still not attempted |
| Spatial error model | Attempted, own weights | The paper doesn't specify the geographic adjacency/weights structure it used, so this repo built its own. See "Validation and robustness checks" below |
| Projection to 2100 (paper's "22% widening" claim) | Substituted, not replicated | The paper's forecasting method isn't disclosed. Figure 5b is this repo's own naive linear extrapolation of each region's mean-gap trend, labeled as such in the plot itself — an illustration of what a straight line implies, not a reproduction of their number |
| UN World Population Prospects demographics | Not yet incorporated | The pipeline uses only WHO indicators (LE, HALE, health expenditure, disease burden) |

## Phase 2: disease-burden clustering

v1 could not attempt the paper's PCA/k-means/Boruta/random-forest section because WHO's simple bulk OData API only exposes years-lived-with-disability (YLD) as global/regional aggregates through 2012 — useless for country-level clustering. The actual country-level, cause-specific data turned out to be reachable after all, just not through that API.

**Source found:** WHO's Global Health Estimates (GHE) 2021 round publishes direct bulk XLSX downloads, one file per year, at predictable URLs under `cdn.who.int/media/docs/default-source/gho-documents/global-health-estimates/ghe2021_yld_bycountry_<year>.xlsx` (linked from the [leading-causes-of-DALYs page](https://www.who.int/data/gho/data/themes/mortality-and-global-health-estimates/global-health-estimates-leading-causes-of-dalys), no API or auth needed). The GHE Results Tool itself is a click-through UI with no discoverable JSON backend; these bulk files are the same underlying data without needing to script the UI.

**What `R/04_pull_disease_burden.R` does:** downloads the YLD file for 2000, 2010, 2015, 2019, 2020, and 2021, and parses the "All ages" sheet — a five-level outline of disability causes (WHO's own numbering, columns 3-7 hold that outline's markers and names depending on depth) by country. It keeps the ~24 mid-level cause categories (Communicable diseases, Cardiovascular diseases, Mental and substance use disorders, and so on — the same resolution a burden-of-disease clustering study would typically use, not the full ~130-row leaf-level list), for the combined-sex "Persons" rows, expressed as YLD per 1000 population.

**What `R/05_disease_burden_clustering.R` does:** standardizes the 2019 cross-section (chosen over 2020-2021 to avoid the COVID-outcomes category that only exists in later years, and because 2019 matches the paper's own window), runs PCA, keeps enough components for 80% cumulative variance, and runs k-means with k chosen by mean silhouette width over k = 2 to 8 — a modeling choice, not a reproduction of one the paper documents, since the paper doesn't state how it picked its cluster count either.

**Result:** k = 2 was the silhouette-preferred split (78 vs. 107 countries), not the paper's reported 3 clusters — a real methodological difference worth sitting with, not something to force into agreement. Cluster 1 (USA, GBR, JPN, DEU, BRA, CHN among others) carries a higher relative burden from musculoskeletal disease and mental/substance-use disorders; cluster 2 (AFG, ETH, IND, NGA among others) carries relatively more infectious-disease burden alongside still-substantial mental and musculoskeletal burden. That split reads like the familiar income/age-structure divide in global disease burden, which is a sensible result, but it is this repo's own answer to "how many clusters," not a check against the paper's.

Full output in `output/tables/disease_burden_clusters.csv` (per-country membership), `disease_burden_cluster_profile.csv` (per-cluster means), and `disease_burden_silhouette_by_k.csv`.

**Still open:** Boruta feature selection specifically, and checking whether a different k or a different clustering method (GMM, hierarchical) changes the story. Random forest validation is now attempted, see below.

## Validation and robustness checks

Both of these use choices this repo made on its own, because the paper does not disclose the choices it made. **Neither is expected to reproduce the paper's specific numbers.** What each can show honestly is whether this repo's own results hold up under a second, independent method, not whether they match the paper's.

### Random forest validation of the disease-burden clusters

The paper validates its (3-cluster) disease-burden clusters with a random forest. This repo's own clustering found k = 2, not 3 (see Phase 2 above), so `R/11_cluster_validation_rf.R` validates *this repo's* 2-cluster split, using default hyperparameters (500 trees) the paper doesn't specify either.

**Result:** out-of-bag accuracy of 98.4% (3 of 183 countries misclassified) — the 2-cluster split is highly separable on the same 22 disease-burden features that produced it, which is a real (if circular-sounding) check: it confirms the clusters are internally coherent, not that k = 2 is "more correct" than the paper's k = 3. Cross-checking which disease categories the random forest found most decisive (musculoskeletal disease, malignant neoplasms, oral conditions, neurological conditions) against the PCA loadings from Figure 3c shows 9 of the top 10 causes agree between the two independent methods, which is reassuring: the random forest and the PCA are describing the same underlying structure, not disagreeing about what separates the clusters. Full output in `output/tables/cluster_rf_importance.csv` and `cluster_rf_validation_summary.txt`.

### A spatial error model, with this repo's own weights

The classic spatial-econometrics stack, `spdep`/`spatialreg`, pulls in `sf`, which fails to build from source in this environment (the same broken GDAL/libtiff/PROJ linkage documented in `R/utils_map.R` for the choropleth maps). `R/12_spatial_error_model.R` falls back to `nlme::gls()` with a `corExp()` spatial correlation structure over country centroid longitude/latitude, an exponential spatial-decay error covariance. This is the same underlying idea as a spatial error model, errors correlated by geographic distance, without needing a formal adjacency matrix or the `sf`/`spdep` toolchain. Centroids are a simple mean of each country's `maps` polygon vertices, not a proper area-weighted centroid, precise enough to place a country relative to its neighbors, not for anything requiring real geographic accuracy.

**Result:** fit against the same `gap ~ life_expectancy + health_exp_pct_gdp` model as Figure 2, both coefficients stay significant and similar in size to the plain-OLS fit, and the model finds a real spatial correlation range (about 17 degrees). Reclassifying every country as larger- or smaller-than-predicted using the spatial model's residuals instead of OLS's flips 8 of 183 countries, 5 of them in Europe (Austria, Cyprus, Czechia, Denmark, the Netherlands, all shift from smaller-than-predicted to larger), which reads as genuine spatial clustering among geographically close European countries, not noise. Full output in `output/figures/fig2d_spatial_adjusted_map.png`, `output/tables/spatial_model_flips.csv`, and `spatial_model_deviations.csv`.

## Figures

All 15 paper-figure panels, plus one robustness-check figure (fig2d), are in `output/figures/`, one PNG per panel rather than composited multi-panel figures. Each is generated by one of `R/06_figure1.R` through `R/10_figure5.R`, or `R/12_spatial_error_model.R` for fig2d.

| Figure | Panel | What it shows | Deviation from the paper |
|---|---|---|---|
| 1 | a | Density of lifespan (LE) vs. healthspan (HALE), by region | 2021 snapshot, not 2019 |
| 1 | b | World choropleth of the gap per country | Map drawn with the `maps`/`mapdata` packages, not `sf`/Natural Earth — the latter's `terra` dependency failed to build from source in this environment (missing libtiff/PROJ linkage). `maps`' country polygons use older/different names than ISO3 codes; 16 of 185 were hand-matched in `R/utils_map.R` (documented there), and Antigua & Barbuda / Trinidad & Tobago each show only their larger island |
| 1 | c | Boxplot of the gap by region, points overlaid | 2021 snapshot |
| 2 | a, b | Maps of countries with a larger/smaller-than-predicted gap | "Predicted" comes from this repo's own regression (`gap ~ life_expectancy + health_exp_pct_gdp`), which omits the paper's third predictor, NCD burden — so the exact set of over/under-predicted countries won't match theirs, even though the method (residuals from a fitted model) is the same idea |
| 2 | c | Regional composition donut for each deviation group | Same caveat as above |
| 2 | d | Deviation map using a spatial error model instead of plain OLS | This repo's own `corExp()` spatial weights over country centroids, not the paper's undisclosed structure — see "Validation and robustness checks" above |
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

Needs R plus `jsonlite`, `dplyr`, `tidyr`, `readxl`, `cluster`, `ggplot2`, `maps`, `mapdata`, `countrycode`, `pheatmap`, `MASS`, `randomForest`, and `nlme`. If you don't have R installed:

```
nix-shell -p R rPackages.jsonlite rPackages.dplyr rPackages.tidyr rPackages.readxl rPackages.cluster rPackages.ggplot2 rPackages.maps rPackages.mapdata rPackages.countrycode rPackages.pheatmap rPackages.MASS rPackages.randomForest rPackages.nlme --run "Rscript run_all.R"
```

Otherwise, from an R session with those packages installed:

```r
source("run_all.R")
```

This pulls fresh data from the WHO API and the GHE bulk files (cached in `data_raw/`, gitignored — the GHE xlsx files alone run ~12MB x 6 years), builds `data_processed/analysis_dataset.csv` and `disease_burden_long.csv`, writes results to `output/tables/`, and writes all 16 figure panels (the 15 paper figures plus the spatial-model robustness check) to `output/figures/`.

## Roadmap

- Incorporate UN WPP demographics
- Boruta feature selection on the disease-burden clusters, as the paper also does alongside its random forest
- Compare k-means against an alternative (GMM, hierarchical) and the silhouette-chosen k against other selection criteria, as a check on how sensitive the clustering is to those choices
- Try alternative spatial weights for the spatial error model (k-nearest-neighbor or inverse-distance instead of `corExp()`'s continuous decay) as a check on how sensitive the 8-country flip count is to that choice
- Revisit the world map and the spatial-econometrics stack (`sf`, `spdep`, `spatialreg`) if their `terra`/GDAL build chain becomes workable in this environment, for finer polygon detail and a more standard spatial error model than the `nlme` approximation provides
