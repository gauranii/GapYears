# GapYears

A partial replication, and 2021 extension, of ["Global variation in the gap between lifespan and healthspan"](https://www.nature.com/articles/s43856-025-01111-2) (*Communications Medicine*, 2025), which measures how many years people live in poor health at the end of life, and how that gap varies by world region.

The paper's data is public. Its code is not, so this is a from-scratch reconstruction from the methods text, not a verified match against a reference implementation. Where the original methodology can't be reproduced cleanly from public data, that's stated below rather than forced.

## What this replicates

- The core metric: healthspan-lifespan gap = life expectancy (LE) − healthy life expectancy (HALE)
- Regional variation in the gap, tested with Kruskal-Wallis and BH-adjusted pairwise comparisons
- A forward-selection linear regression on gap predictors

## What this does not attempt, and why

| Original component | Status | Reason |
|---|---|---|
| PCA / k-means clustering on disease burden | Not attempted (v2 candidate) | Needs country-level, cause-specific years-lived-with-disability (YLD) data. WHO's bulk OData API only exposes YLD as global/regional aggregates through 2012 — the disaggregated data lives in WHO's separate [Global Health Estimates Results Tool](https://www.who.int/data/global-health-estimates), which isn't reachable through the same simple pull |
| Random forest validation / Boruta feature selection | Not attempted | Same dependency as above |
| Spatial error model | Not attempted | The paper doesn't specify the geographic adjacency/weights structure it used; any reconstruction would be a guess, not a replication |
| Projection to 2100 (paper's "22% widening" claim) | Not attempted | Forecasting method isn't detailed in the paper |
| UN World Population Prospects demographics | Not yet incorporated | v1 uses only WHO indicators (LE, HALE, health expenditure) |

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

Needs R plus the `jsonlite` and `dplyr` packages. If you don't have R installed:

```
nix-shell -p R rPackages.jsonlite rPackages.dplyr --run "Rscript run_all.R"
```

Otherwise, from an R session with those packages installed:

```r
source("run_all.R")
```

This pulls fresh data from the WHO API (cached in `data_raw/`, gitignored), builds `data_processed/analysis_dataset.csv`, and writes results to `output/tables/`.

## Roadmap

- Locate and script a pull against WHO's GHE Results Tool for country-level, cause-specific YLD data, to attempt the disease-burden PCA/clustering section
- Incorporate UN WPP demographics
- Once burden data is in hand, compare k-means against an alternative (GMM, hierarchical) and Boruta against LASSO/elastic net, as a check on how sensitive the paper's conclusions are to those method choices
