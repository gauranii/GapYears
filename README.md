# GapYears

A partial replication, and 2021 extension, of ["Global variation in the gap between lifespan and healthspan"](https://www.nature.com/articles/s43856-025-01111-2) (*Communications Medicine*, 2025), which measures how many years people live in poor health at the end of life, and how that gap varies by world region.

The paper's data is public. Its code is not, so this is a from-scratch reconstruction from the methods text, not a verified match against a reference implementation. Where the original methodology can't be reproduced cleanly from public data, that's stated below rather than forced.

## What this replicates

- The core metric: healthspan-lifespan gap = life expectancy (LE) − healthy life expectancy (HALE)
- Regional variation in the gap, tested with Kruskal-Wallis and BH-adjusted pairwise comparisons
- A forward-selection linear regression on gap predictors
- A disease-burden PCA + k-means clustering of countries (phase 2 — see below), using real cause-specific YLD data, not attempted in v1
- All 5 of the paper's main-text figures, redrawn from this repo's own numbers (see Figures below) — panel-for-panel where the underlying method is reproducible, clearly-labeled substitutes where it isn't
- A panel regression using the full 2000-2021 data (see "A panel regression, beyond the paper's own methods" below) — this repo's own extension, not something the paper itself does

## What this does not attempt, and why

| Original component | Status | Reason |
|---|---|---|
| Random forest validation of the disease-burden clusters | Attempted, own hyperparameters | See "Validation and robustness checks" below |
| Boruta feature selection on the disease-burden clusters | Attempted, own settings | See "Validation and robustness checks" below |
| Spatial error model | Attempted, own weights | The paper doesn't specify the geographic adjacency/weights structure it used, so this repo built its own. See "Validation and robustness checks" below |
| Projection to 2100 (paper's "22% widening" claim) | Substituted, not replicated | The paper's forecasting method isn't disclosed. Figure 5b is this repo's own naive linear extrapolation of each region's mean-gap trend, labeled as such in the plot itself — an illustration of what a straight line implies, not a reproduction of their number |
| UN World Population Prospects demographics | Attempted, blocked | See "UN WPP: what was tried, and the actual wall" below |

## Phase 2: disease-burden clustering

v1 could not attempt the paper's PCA/k-means/Boruta/random-forest section because WHO's simple bulk OData API only exposes years-lived-with-disability (YLD) as global/regional aggregates through 2012 — useless for country-level clustering. The actual country-level, cause-specific data turned out to be reachable after all, just not through that API.

**Source found:** WHO's Global Health Estimates (GHE) 2021 round publishes direct bulk XLSX downloads, one file per year, at predictable URLs under `cdn.who.int/media/docs/default-source/gho-documents/global-health-estimates/ghe2021_yld_bycountry_<year>.xlsx` (linked from the [leading-causes-of-DALYs page](https://www.who.int/data/gho/data/themes/mortality-and-global-health-estimates/global-health-estimates-leading-causes-of-dalys), no API or auth needed). The GHE Results Tool itself is a click-through UI with no discoverable JSON backend; these bulk files are the same underlying data without needing to script the UI.

**What `R/04_pull_disease_burden.R` does:** downloads the YLD file for 2000, 2010, 2015, 2019, 2020, and 2021, and parses the "All ages" sheet — a five-level outline of disability causes (WHO's own numbering, columns 3-7 hold that outline's markers and names depending on depth) by country. It keeps the ~24 mid-level cause categories (Communicable diseases, Cardiovascular diseases, Mental and substance use disorders, and so on — the same resolution a burden-of-disease clustering study would typically use, not the full ~130-row leaf-level list), for the combined-sex "Persons" rows, expressed as YLD per 1000 population.

**What `R/05_disease_burden_clustering.R` does:** standardizes the 2019 cross-section (chosen over 2020-2021 to avoid the COVID-outcomes category that only exists in later years, and because 2019 matches the paper's own window), runs PCA, keeps enough components for 80% cumulative variance, and runs k-means with k chosen by mean silhouette width over k = 2 to 8 — a modeling choice, not a reproduction of one the paper documents, since the paper doesn't state how it picked its cluster count either.

**Result:** k = 2 was the silhouette-preferred split (78 vs. 107 countries), not the paper's reported 3 clusters — a real methodological difference worth sitting with, not something to force into agreement. Cluster 1 (USA, GBR, JPN, DEU, BRA, CHN among others) carries a higher relative burden from musculoskeletal disease and mental/substance-use disorders; cluster 2 (AFG, ETH, IND, NGA among others) carries relatively more infectious-disease burden alongside still-substantial mental and musculoskeletal burden. That split reads like the familiar income/age-structure divide in global disease burden, which is a sensible result, but it is this repo's own answer to "how many clusters," not a check against the paper's.

Full output in `output/tables/disease_burden_clusters.csv` (per-country membership), `disease_burden_cluster_profile.csv` (per-cluster means), and `disease_burden_silhouette_by_k.csv`.

**Still open:** checking whether a different k or a different clustering method (GMM, hierarchical) changes the story. Random forest validation and Boruta feature selection are now both attempted, see below.

### Tracking cluster membership over time

Everything above clusters a single year, 2019. `R/17_cluster_membership_over_time.R` reruns the same pipeline, k fixed at 2 (this repo's bootstrap-confirmed answer, see "Bootstrapping the k = 2 vs. k = 3 question" below), on 2000, 2010, 2015, and 2019 (2020-2021 skipped, same COVID-category distortion noted above), to ask whether countries move between the two clusters over time rather than only looking at one snapshot. Not something the paper does; this repo's own tracking exercise. k-means labels are arbitrary per run, so each year's clustering is aligned back to the year after it by maximum country-overlap, anchored to the published 2019 result above, before any transition is reported — see the script for the alignment method.

**Result:** 22 of 185 countries changed cluster between their earliest and latest observed year, and every single one of them moved the same direction, from the communicable-heavy cluster toward the noncommunicable-heavy one, never the reverse. Ten of the 22 are in the Americas (Colombia, Costa Rica, Ecuador, Grenada, Saint Lucia, Mexico, Panama, Peru, Trinidad and Tobago, Saint Vincent and the Grenadines), with the rest spread across Eastern Mediterranean, Western Pacific, Europe, South-East Asia, and one in Africa. A unanimous direction across 22 independent countries, with no countervailing movement at all, reads as a real epidemiological transition in progress, not resampling noise, though 22 countries out of 185 over 19 years is also a modest, gradual shift, not a wholesale reordering of the disease-burden map. Full output in `output/tables/cluster_membership_by_year.csv`, `cluster_membership_movers.csv`, and `cluster_membership_transitions.csv`.

## Validation and robustness checks

Both of these use choices this repo made on its own, because the paper does not disclose the choices it made. **Neither is expected to reproduce the paper's specific numbers.** What each can show honestly is whether this repo's own results hold up under a second, independent method, not whether they match the paper's.

### Random forest validation of the disease-burden clusters

The paper validates its (3-cluster) disease-burden clusters with a random forest. This repo's own clustering found k = 2, not 3 (see Phase 2 above), so `R/11_cluster_validation_rf.R` validates *this repo's* 2-cluster split, using default hyperparameters (500 trees) the paper doesn't specify either.

**Result:** out-of-bag accuracy of 98.4% (3 of 183 countries misclassified) — the 2-cluster split is highly separable on the same 22 disease-burden features that produced it, which is a real (if circular-sounding) check: it confirms the clusters are internally coherent, not that k = 2 is "more correct" than the paper's k = 3. Cross-checking which disease categories the random forest found most decisive (musculoskeletal disease, malignant neoplasms, oral conditions, neurological conditions) against the PCA loadings from Figure 3c shows 9 of the top 10 causes agree between the two independent methods, which is reassuring: the random forest and the PCA are describing the same underlying structure, not disagreeing about what separates the clusters. Full output in `output/tables/cluster_rf_importance.csv` and `cluster_rf_validation_summary.txt`.

### Boruta feature selection on the disease-burden clusters

The paper also runs Boruta feature selection alongside its random forest. `R/13_boruta_feature_selection.R` runs it on the same 22 disease-burden categories and this repo's own k = 2 split, using Boruta's default settings, which the paper doesn't specify either.

**Result:** 20 of 22 categories confirmed important, 1 tentative (intentional injuries), 1 rejected (skin diseases) — with this few features and only two well-separated clusters, Boruta confirming most of them is itself a believable outcome, not a sign the test did nothing. The more informative number is the overlap with the random forest above: Boruta's top 10 confirmed causes by importance and the random forest's top 10 by `MeanDecreaseGini` are the *same 10*, 10 of 10, just in a slightly different order. Two independently-implemented feature-selection methods landing on an identical top-10 list is a stronger form of agreement than either check alone, and lines up with the same musculoskeletal/malignant-neoplasm/cardiovascular axis Figure 3c's PCA loadings already pointed at. Full output in `output/tables/cluster_boruta_decisions.csv` and `cluster_boruta_summary.txt`.

### Bootstrapping the k = 2 vs. k = 3 question

`R/05_disease_burden_clustering.R`'s k = 2 answer, versus the paper's reported k = 3, comes from one silhouette test on one sample of 185 countries. `R/16_bootstrap_cluster_k.R` asks how much that answer would move under resampling: 200 bootstrap draws of countries (with replacement, the standard bootstrap; a resample containing duplicate countries is expected, not a bug), the same PCA + k-means + silhouette pipeline rerun on each, and the winning k tabulated across all 200.

**Result:** k = 2 wins 94% of the 200 resamples (188 of 200). k = 3, the paper's own reported count, wins only 1% (2 of 200); the small remainder scatters across k = 4 and k = 5. This is not a coin-flip result that happened to land on 2. The silhouette test's preference for two clusters over three is stable under resampling, which makes the k = 2 vs. k = 3 divergence from the paper a real methodological difference this repo is confident in, not sampling noise that a different draw of countries could have easily flipped. Full output in `output/tables/cluster_k_bootstrap.csv` and `cluster_k_bootstrap_summary.txt`.

### Moran's I: does the OLS residual map actually show spatial autocorrelation

Before fitting a spatial model at all, it's worth asking whether the plain-OLS residuals mapped in Figure 2 actually show spatial autocorrelation, geographically close countries having more similar residuals than chance predicts, or whether that was assumed rather than checked. `R/18_morans_i.R` computes Moran's I directly (a simple formula, implemented in base R rather than a package, since `spdep`'s own Moran's I implementation is blocked by the same `sf` build failure described below) on the same OLS residuals, using inverse-squared-distance weights over the same crude centroids `R/12_spatial_error_model.R` builds, with significance from a 999-permutation test rather than the asymptotic approximation.

**Result:** Moran's I = 0.354, permutation p = 0.011 — significant positive spatial autocorrelation. Geographically close countries really do have more similar residuals than chance alone would produce. This is the formal justification for attempting a spatial model at all, and it lines up with what `R/12_spatial_error_model.R` finds independently: a real fitted spatial correlation structure and 8 countries that reclassify once it's accounted for. Full output in `output/tables/morans_i_residuals.csv` and `morans_i_summary.txt`.

### A spatial error model, with this repo's own weights

The classic spatial-econometrics stack, `spdep`/`spatialreg`, pulls in `sf`, which fails to build from source in this environment (the same broken GDAL/libtiff/PROJ linkage documented in `R/utils_map.R` for the choropleth maps). `R/12_spatial_error_model.R` falls back to `nlme::gls()` with a `corExp()` spatial correlation structure over country centroid longitude/latitude, an exponential spatial-decay error covariance. This is the same underlying idea as a spatial error model, errors correlated by geographic distance, without needing a formal adjacency matrix or the `sf`/`spdep` toolchain. Centroids are a simple mean of each country's `maps` polygon vertices, not a proper area-weighted centroid, precise enough to place a country relative to its neighbors, not for anything requiring real geographic accuracy.

**Result:** fit against the same `gap ~ life_expectancy + health_exp_pct_gdp` model as Figure 2, both coefficients stay significant and similar in size to the plain-OLS fit, and the model finds a real spatial correlation range (about 17 degrees). Reclassifying every country as larger- or smaller-than-predicted using the spatial model's residuals instead of OLS's flips 8 of 183 countries, 5 of them in Europe (Austria, Cyprus, Czechia, Denmark, the Netherlands, all shift from smaller-than-predicted to larger), which reads as genuine spatial clustering among geographically close European countries, not noise. Full output in `output/figures/fig2d_spatial_adjusted_map.png`, `output/tables/spatial_model_flips.csv`, and `spatial_model_deviations.csv`.

### UN WPP: what was tried, and the actual wall

This was attempted, not skipped. The UN Population Division's newer Data Portal API (`population.un.org/dataportalapi/api/v1/`) has two tiers, confirmed directly rather than assumed: `GET /indicators/` and `GET /locations/` (metadata: indicator definitions, country ISO3 codes) are open, no auth needed, and returned clean data for indicators relevant here (id 49 total population, id 67 median age, id 84 old-age dependency ratio, all 1950-2100). The actual `GET /data/indicators/{id}/locations/{loc}/start/{y}/end/{y}` endpoint, the one that returns real values rather than metadata, returned `401` with an explicit `WWW-Authenticate: Bearer` header on every request tried, across multiple indicator IDs and both ISO3 and M49 location-code formats. That header is unambiguous: this tier requires a bearer token this repo does not have, not a URL this repo guessed wrong.

The older static bulk-download route the paper itself cites (`population.un.org/wpp/Download/Standard/MostUsed/`) is now an Angular single-page app with no server-rendered links, so there is no static file URL to discover without executing its JavaScript, which this environment cannot do. Several plausible bulk-file names were tried directly against the asset path and all returned `404`.

**What would unblock this:** registering for a free UN Data Portal API key (a manual, human step this repo cannot complete on its own) and passing it as a bearer token to the `/data/` endpoint above; the metadata endpoints already confirm the indicators and country coverage this repo needs are there once that key exists.

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
| 5 | c | Same 2100 projection, three methods compared per region | See "Comparing projection methods for 2100" under Extensions below |

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

## Extensions beyond the paper's own methods

Neither the original paper nor this repo's own v1/phase-2 work attempts any of the things in this section. All are this repo's own additions, using data already on hand, not replications of anything the paper does.

### A panel regression

Neither this repo nor the original paper goes past a single-year cross-section for the gap ~ predictors regression above. `R/14_panel_regression.R` uses the full 2000-2021 country-year panel already pulled in phase 1 rather than only the latest year.

The question a cross-sectional regression answers, do countries with higher life expectancy and health spending have a wider gap, is not the same question a country fixed-effects panel model answers: within the same country, does the gap widen in the years its own life expectancy or spending rises, holding every time-invariant thing about that country, geography, history, baseline health-system quality, fixed. The second question is generally the more credible one, since it can't be confounded by whatever makes some countries permanently different from others.

**Result:** life expectancy's coefficient is remarkably stable across a single-year cross-section (0.158), a pooled-OLS fit across all 22 years (0.146), and the country fixed-effects model (0.145) — the relationship holds up whether it's estimated from differences between countries or from changes within one country over time. Health spending's coefficient does not survive that test as cleanly: 0.053 in the cross-section, 0.062 pooled, but only 0.022 under fixed effects, less than half its cross-sectional size, though still statistically significant (p < 1e-24). A Hausman test confirms fixed effects is the appropriate model here (χ² = 9.03, p = 0.011), meaning the random-effects assumption, that a country's unobserved characteristics are uncorrelated with its life expectancy and spending, is rejected, about as expected as a Hausman test result gets. Read together, this says life expectancy's relationship to the gap is not just a between-country pattern, health spending's cross-sectional relationship is partly, not fully, a between-country pattern that shrinks once each country is compared only against its own history. Full coefficient tables in `output/tables/panel_regression_coefficients.csv` and `panel_regression_summary.txt`.

### Quantile regression on the gap predictors

`R/03_analysis.R`'s OLS regression describes the *average* relationship between the predictors and the gap. `R/15_quantile_regression.R` fits the same gap ~ life_expectancy + health_exp_pct_gdp relationship at five points in the gap's own distribution (the 10th, 25th, 50th, 75th, and 90th percentiles), asking whether that relationship looks the same for countries that already have a narrow gap as it does for countries that already have a wide one.

**Result:** life expectancy's coefficient is stable and highly significant at every single quantile (0.155 to 0.165, p < 1e-12 throughout), the same stability the panel model above found from a completely different angle. Health spending's coefficient is not stable across the distribution at all: it is small and not statistically significant at the 10th, 25th, and 50th percentiles (p = 0.54, 0.43, 0.71), then becomes larger and clearly significant at the 75th and 90th (0.055 and 0.054, p = 1.5e-4 and p = 0.03). Put plainly, health spending's apparent relationship to the gap in the OLS average is not a relationship that holds for a typical or narrow-gap country. It is concentrated almost entirely among the countries that already have the widest gaps, a pattern the average alone hides completely. Full output in `output/tables/quantile_regression_coefficients.csv` and `quantile_regression_summary.txt`.

### LASSO / elastic net using disease categories as direct gap predictors

The paper's own gap regression uses one aggregate noncommunicable-disease-burden variable. This repo's phase-2 work has the full 22-category disaggregated cause-specific data behind that aggregate. `R/19_lasso_gap_predictors.R` asks a question the paper's single variable cannot answer: which *specific* diseases predict the gap directly, not clustering countries by disease profile (that's Figure 3/4's question), but predicting the gap itself from all 22 causes at once, with a LASSO and an elastic net choosing which of them earn a nonzero coefficient. This is a different question from what the random forest and Boruta checks above ask: those ask which causes separate the two disease-burden *clusters*; this asks which causes predict the *gap*, net of the others, in one regression. Agreement or disagreement between the two is informative either way, not something to force into alignment.

**Result:** 12 of 22 causes survive at the conservative `lambda.1se` LASSO fit, not a dramatically sparse model, which is itself worth reporting plainly rather than expecting or engineering a cleaner story. "Other neoplasms" carries by far the largest-magnitude coefficient, negative and several times the size of anything else, with mental and substance-use disorders, musculoskeletal disease, cardiovascular disease, and neurological conditions among the next largest. Of the 12 causes LASSO selects, 6 also appear in the random forest's top 10 for the cluster-separation question (musculoskeletal disease, malignant neoplasms is not among them but other neoplasms is, neurological conditions, cardiovascular disease, digestive diseases, sense organ diseases), a partial but real overlap between "what separates the clusters" and "what predicts the gap directly," not a coincidence, but not identical questions either. Full output in `output/tables/lasso_gap_predictors_coefficients.csv` and `lasso_gap_predictors_summary.txt`.

### Comparing projection methods for 2100

Figure 5b's naive linear extrapolation is one modeling choice among several defensible ones, chosen because the paper does not disclose its own projection method (see Figures above). `R/20_projection_model_comparison.R` fits two more time-series methods, ARIMA (order auto-selected per region by `forecast::auto.arima`) and ETS/exponential smoothing (`forecast::ets`), on the same 2000-2021 regional mean-gap series, and forecasts all three out to 2100 side by side. This is not an attempt to guess the paper's method either; it directly answers a narrower, honest question: how much does the 2100 endpoint move if a different, equally reasonable method is used on the identical data.

**Result:** it moves a lot. Averaged across all six regions (simple mean, not population-weighted, since the paper doesn't confirm its own 22% figure is population-weighted either), the naive linear method projects the gap widening **37.4%** by 2100. ETS projects **11.3%**. ARIMA projects **9.0%**. The paper's own reported "22% by 2100" sits between these three, closer to the middle than to any single one of them, which is itself the point: a single projected percentage, without the method that produced it disclosed, could plausibly have come from anywhere in a range this wide. Per-region, the spread is uneven rather than uniform. Africa, Europe, and Eastern Mediterranean show real divergence between methods (up to 4-13 years apart by 2100 depending on region and method); South-East Asia and Western Pacific show the three methods staying close together, under half a year apart. One region's ARIMA fit, the Americas, extrapolates into an implausible negative gap by 2100, an honest limitation of automatic long-horizon extrapolation from a 22-point annual series worth stating plainly rather than hiding: not every automatically-selected model produces a sensible answer 79 years out, which is itself evidence for treating any single point estimate this far out with real caution, this repo's own naive linear line included. Full output in `output/figures/fig5c_projection_model_comparison.png`, `output/tables/projection_2100_by_method.csv`, and `projection_2100_global_pct_change.csv`.

## Reproducing this

Needs R plus `jsonlite`, `dplyr`, `tidyr`, `readxl`, `cluster`, `ggplot2`, `maps`, `mapdata`, `countrycode`, `pheatmap`, `MASS`, `randomForest`, `nlme`, `Boruta`, `plm`, `quantreg`, `glmnet`, and `forecast`.

With Nix (recommended, this is what every script in this repo was actually run with):

```
nix develop --command Rscript run_all.R
```

`flake.nix` pins all 17 packages into one `rWrapper` environment (`nix flake check` and a full clean `run_all.R` pass both verified against it). `nix develop` alone drops into a shell with `Rscript` and every dependency on `PATH`. Without a flake-enabled Nix, the equivalent one-liner:

```
nix-shell -p R rPackages.jsonlite rPackages.dplyr rPackages.tidyr rPackages.readxl rPackages.cluster rPackages.ggplot2 rPackages.maps rPackages.mapdata rPackages.countrycode rPackages.pheatmap rPackages.MASS rPackages.randomForest rPackages.nlme rPackages.Boruta rPackages.plm rPackages.quantreg rPackages.glmnet rPackages.forecast --run "Rscript run_all.R"
```

Otherwise, from an R session with those packages installed:

```r
source("run_all.R")
```

This pulls fresh data from the WHO API and the GHE bulk files (cached in `data_raw/`, gitignored — the GHE xlsx files alone run ~12MB x 6 years), builds `data_processed/analysis_dataset.csv` and `disease_burden_long.csv`, writes results to `output/tables/`, and writes all 16 figure panels (the 15 paper figures plus the spatial-model robustness check) to `output/figures/`.

## Roadmap

- Retry UN WPP demographics with a registered API key (see "UN WPP: what was tried, and the actual wall" above) — the metadata endpoints confirm the indicators and coverage are there, the blocker is credentials, not data availability
- Compare k-means against an alternative clustering method (GMM, hierarchical) — the bootstrap above checks how stable k = 2 is under resampling of the same method, not whether a different method would agree
- Try alternative spatial weights for the spatial error model (k-nearest-neighbor or inverse-distance instead of `corExp()`'s continuous decay) as a check on how sensitive the 8-country flip count is to that choice
- Revisit the world map and the spatial-econometrics stack (`sf`, `spdep`, `spatialreg`) if their `terra`/GDAL build chain becomes workable in this environment, for finer polygon detail and a more standard spatial error model than the `nlme` approximation provides
