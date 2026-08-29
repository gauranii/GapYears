# Release-readiness plan — GapYears

**Status:** §1 (tests), §2 (CI), most of §3 (LICENSE, CITATION.cff, sessionInfo capture),
and §4 (error handling) are done — see commits/working tree. Remaining: cut the `v1.0.0`
git tag/GitHub release once this is reviewed and merged (a repo-owner action, not done here).
`tests/testthat.R` has 51 passing tests; `nix flake check` and a full `run_all.R` re-run
(against the cached `data_raw/`) both pass, and pipeline outputs are confirmed byte-identical
to pre-change outputs except where a real bug was found and fixed (see note below).

## Changes made

**New files**

- `tests/testthat.R` — test runner entry point (`nix develop --command Rscript tests/testthat.R`).
- `tests/testthat/test-parse_ghe_yld.R` — GHE xlsx-parsing logic, against a synthetic fixture.
- `tests/testthat/test-combine_dataset.R` — LE/HALE/GDP join logic (dropped/kept rows, gap calc, dedup).
- `tests/testthat/test-align_to_reference.R` — cross-year cluster-label alignment (identity/swap/tie cases).
- `tests/testthat/test-morans_i.R` — the from-scratch Moran's I formula, against hand-derivable cases.
- `tests/testthat/test-clustering-utils.R` — shared PCA/silhouette k-selection, against synthetic clusters.
- `tests/testthat/test-map-fixes.R` — `MAP_NAME_FIXES`/`REGION_ABBR` completeness against the `maps` package and the committed dataset.
- `tests/testthat/test-data-invariants.R` — schema/sanity checks on the committed `data_processed/*.csv` files.
- `tests/testthat/test-validate_who_response.R` — the new WHO API response validation.
- `R/utils_clustering.R` — shared PCA-scores/silhouette-k-selection/cluster-label-alignment functions, pulled out of `R/05`, `R/16`, `R/17` (was duplicated three times).
- `R/utils_spatial.R` — the Moran's I formula, pulled out of `R/18`.
- `.github/workflows/ci.yml` — runs `nix flake check` + the test suite on every push/PR.
- `.github/workflows/full-pipeline.yml` — runs the full live-data `run_all.R` weekly/on manual dispatch only.
- `LICENSE` — MIT (my call; flagging it since it's your repo — happy to swap if you'd rather use something else).
- `CITATION.cff` — cites this repo, points to the original paper for the original findings.

**Edited files**

- `R/02_build_dataset.R` — split `build_dataset()`'s join logic out into a pure `combine_dataset(le, hale, gdp)`, with a `distinct(iso3, year)` guard on each input against a duplicate upstream row silently multiplying the join.
- `R/04_pull_disease_burden.R` — split `parse_ghe_yld()` into I/O (`parse_ghe_yld()`) + pure parsing (`parse_ghe_yld_raw()`); `download_ghe_yld()` now checks the download status and file size before trusting a cached xlsx (guards against a truncated/error-page download being silently cached and reused); added a longer connection timeout.
- `R/01_pull_data.R` — `pull_who_indicator()` now validates the API response shape (non-empty, expected columns present) before caching it; added a longer connection timeout.
- `R/05_disease_burden_clustering.R` — now calls into `R/utils_clustering.R` instead of inline PCA/silhouette code; reassigns `feature_matrix`/`pca` from the shared function's result so `R/08_figure3.R` and `R/11_cluster_validation_rf.R` (which read those back out of this script's global environment after sourcing it) still see the zero-variance-column-reduced versions — this was a real bug during the refactor (see below), now fixed and verified.
- `R/16_bootstrap_cluster_k.R` — `best_k_for()` now calls the shared `R/utils_clustering.R` functions instead of duplicating the PCA/silhouette pipeline.
- `R/17_cluster_membership_over_time.R` — `cluster_one_year()` now calls the shared PCA helper; local `align_to_reference()` removed in favor of the shared, tested one.
- `R/18_morans_i.R` — local `morans_i()` removed in favor of the shared, tested one in `R/utils_spatial.R`.
- `run_all.R` — writes `output/session_info.txt` (R version + loaded package versions) at the end of a full run.
- `flake.nix` — added `testthat` to the pinned R package set.
- `README.md` — added a "Tests" section and a "License" section (code is MIT; WHO-derived data in `data_processed/`/`output/tables/` is subject to WHO's own terms).

**Bug found and fixed during the refactor**

Pulling the PCA/silhouette logic out of `R/05_disease_burden_clustering.R` initially broke it: `R/08_figure3.R` and `R/11_cluster_validation_rf.R` both source `R/05` and then read `feature_matrix`/`pca` directly out of its global environment (not via a return value, since `R/05` is a flat script). The first version of the refactor computed the zero-variance-column-reduced matrix and PCA *inside* `pca_scores_for_clustering()` without exposing them back, so those two scripts silently got the wrong (unreduced) `feature_matrix` — which crashed `R/08`'s heatmap (`hclust`: NA/Inf) and would have corrupted `disease_burden_cluster_profile.csv` with two zero-variance causes that should have been dropped. Fixed by having `pca_scores_for_clustering()` return both, and reassigning them in `R/05`. Caught by running the full pipeline end-to-end (not by the unit tests, which is itself worth noting: unit-testing the pure function was necessary but not sufficient here — it didn't cover the cross-script global-environment coupling).

Context: this is a solo-author R research-replication repo (20 sequential scripts run via
`run_all.R`, no package structure, no test suite, no CI). The README is already excellent —
thorough, honest about deviations, and reproducible via Nix. What's missing is the stuff that
protects that quality once the repo is public and no longer just running on one machine: tests
for the fragile parts, a license, and a way to catch silent breakage.

Ordered by priority. Test coverage first, as requested.

## 1. Test coverage (highest priority)

There's no `tests/` directory and no `testthat` dependency today. Add one — this doesn't need to
be an R package to use `testthat::test_dir("tests")` standalone. Focus tests on logic that is
*hand-written and easy to silently break*, not on re-verifying what WHO's data says.

**High-value targets, roughly in order:**

- **`parse_ghe_yld()` (`R/04_pull_disease_burden.R`)** — the riskiest function in the repo. It
  locates header rows by string match, infers outline depth from which of 5 columns is non-NA,
  and slices country columns by fixed position (`8:ncol(raw)`). If WHO reshuffles a column or
  adds a row, this fails silently (wrong depth, wrong causes, no error) rather than loudly. Build
  a small synthetic XLSX fixture (~4 countries, ~6 causes, 3 outline levels, a Population row)
  and assert: correct cause count/names at depth 3, correct `rate_per_1000` arithmetic, correct
  handling of a row where multiple name columns are non-NA (shouldn't happen, but assert it
  doesn't crash confusingly).
- **`build_dataset()` (`R/02_build_dataset.R`)** — join logic (`inner_join` on LE/HALE,
  `left_join` on GDP), the `gap` calculation, and the `filter(!is.na(gap))` step. Feed in small
  synthetic data frames covering: a country present in LE but not HALE (should drop), a country
  missing GDP (should keep, with `NA` gdp), duplicate iso3-year pairs (should not silently
  double-count).
- **`iso3_to_map_region()` / `MAP_NAME_FIXES` (`R/utils_map.R`)** — assert every one of the 16
  hardcoded fixes still resolves to a name that exists in `maps::world.cities`/the `maps` package
  polygon list. This is exactly the kind of thing that breaks quietly on a `maps` package upgrade.
- **Cluster-label alignment (`align_to_reference()` in `R/17_cluster_membership_over_time.R`)** —
  pure function, easy to unit test in isolation: construct two small target/reference data frames
  where the correct alignment is known by construction (identity case and swap case), assert it
  picks the right one. This logic silently produces a *plausible but wrong* answer if broken
  (labels flip), which is worse than a crash — highest-value test in the whole repo for that
  reason.
- **Moran's I base-R implementation (`R/18_morans_i.R`)** — it exists specifically because
  `spdep` isn't available, so there's no reference implementation to check against locally. Test
  it against a hand-computed small example (e.g. 4-5 points on a line/grid with known weights) or
  against published Moran's I values for a textbook toy dataset, so a future edit can't silently
  break the formula.
- **`REGION_ABBR` / `MAP_NAME_FIXES` completeness** — a cheap but valuable test: assert
  `setdiff(unique(dataset$region), names(REGION_ABBR))` is empty, and similarly that every ISO3 in
  `analysis_dataset.csv` either round-trips through `countrycode()` or has an entry in
  `MAP_NAME_FIXES`. Turns "16 countries needed hand fixes, silently 17 next time WHO adds a
  country" into a loud CI failure instead of a wrong map.

**Pipeline-level (not unit tests, but same `tests/` directory):**

- A **schema/invariant test** on `data_processed/analysis_dataset.csv` and
  `disease_burden_long.csv` after a pipeline run: expected columns and types present, `gap >= 0`
  for all rows (a negative gap is almost certainly a data error, not a real finding), `year` within
  expected range, no duplicate `(iso3, year)` pairs, region is one of the 6 known WHO regions.
  Cheap to write, catches an entire class of "WHO changed something upstream" bugs immediately.
- A **golden-file test on deterministic outputs only** — not on live-pulled WHO numbers (those are
  expected to drift as WHO revises history, per the README), but on things computed purely from
  fixed logic: e.g. given a fixed synthetic `disease_burden_long.csv` fixture, does
  `R/05_disease_burden_clustering.R`'s silhouette-selection code pick the expected k. Keeps the
  *methodology* pinned even though the *data* is allowed to move.

**Explicitly not worth testing:** the live network pulls (`pull_who_indicator`,
`download_ghe_yld`) beyond a smoke test with a mocked/local fixture — hitting the real WHO API in
a test suite makes it slow and flaky. Cache a small fixture file instead.

## 2. CI

- Add `.github/workflows/ci.yml` using `cachix/install-nix-action` (or similar) to: `nix flake
  check`, then run the new `testthat` suite via `nix develop --command Rscript -e
  'testthat::test_dir("tests")'`.
- Consider a **separate, manually-triggered or weekly** workflow that runs the full
  `run_all.R` end-to-end against live WHO endpoints — valuable as an early warning that an
  upstream API/file format changed, but too slow/network-dependent to run on every push.
- Gate this on the tests in §1 existing first; a green CI badge with zero tests would be worse
  than no badge.

## 3. Release hygiene

- **Add a `LICENSE` file.** There is none right now, which technically means "all rights
  reserved" — a problem for a repo meant to be publicly reproducible. Code license (MIT/Apache-2.0
  is standard for research code) is a separate question from the WHO data's own reuse terms;
  worth a one-line note in the README on the latter (WHO GHO/GHE data terms) since the repo
  redistributes derived data (`data_processed/`, `output/tables/`) but not the raw WHO files
  themselves (already gitignored).
- **Add a `CITATION.cff`** so the repo is citable, and to keep the distinction clear between "cite
  this replication" vs. "cite the original *Communications Medicine* paper" — README already links
  the paper but a CITATION file is the standard machine-readable form.
- **Tag a release.** `run_all.R` and every script header already say `Release Version: 1.0.0.0` —
  once §1–2 land, cut an actual `v1.0.0` git tag / GitHub release so that version string means
  something concrete and citable, rather than being aspirational text in a header comment.
- **`sessionInfo()` capture.** Add one line to `run_all.R` writing `sessionInfo()` (or better,
  `nix flake metadata`'s output, since Nix already pins exact versions) to
  `output/session_info.txt`. Cheap, and it's the detail a reader needs if they hit a numeric
  mismatch six months from now and want to know what actually ran.

## 4. Error handling in the data-pull scripts

Low urgency relative to §1–3 (this is a script the author reruns themselves, not a service), but
worth doing before calling it release-ready since these are the first things an outside user will
run and the current failure mode is a confusing low-level error, not a clear message:

- `download.file()` in `R/04_pull_disease_burden.R` doesn't check the HTTP status or resulting
  file size — a WHO CDN hiccup silently caches a truncated/HTML-error-page file as if it were the
  real xlsx, and the failure surfaces later as a cryptic `read_excel` parse error. Check
  `download.file()`'s return value and/or the downloaded file size before trusting the cache.
- `pull_who_indicator()` in `R/01_pull_data.R` doesn't check the API response shape before
  caching it — an API error response (e.g. rate-limited, schema change) would get cached as
  truncated/malformed data and silently reused on every subsequent run until `data_raw/` is
  cleared by hand. Add a minimal shape check (`nrow > 0`, expected columns present) before
  `saveRDS()`.
- Both scripts' `download`/`pull` functions have no timeout or retry; a flaky connection just
  hangs. Not urgent to fix, but worth at least a documented timeout via `options(timeout = ...)`.

## 5. Already tracked, not duplicating here

The README's own "Roadmap" section already lists real open methodological questions (UN WPP
credentials, alternative clustering methods, alternative spatial weights, revisiting `sf`/`spdep`).
Those are research-scope decisions, not release blockers — leaving them as-is with the README's
existing honest framing is the right call for a v1.0.0 release; they're follow-up work, not gaps
in this release.

## Suggested order of work

1. Set up `tests/` + `testthat`, write the fixture-based tests for `parse_ghe_yld()` and
   `align_to_reference()` first (highest silent-failure risk).
2. Round out the rest of §1 (join logic, map-fix completeness, Moran's I, schema invariants).
3. Wire up CI (§2) once tests exist to run.
4. LICENSE + CITATION.cff (§3) — quick, unblocks calling this a real release.
5. Error handling in pull scripts (§4) — do alongside or after, lower urgency.
6. Tag `v1.0.0`.
