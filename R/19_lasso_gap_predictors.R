#------------------------------------------------------------------------------------------
#   Project             : Replicating the Healthspan-Lifespan Gap Study
#   Repository          : GapYears
#   Release Version     : 1.0.0.0
#   Author              : Iris Ivy Gauran
#   Description         : LASSO/Elastic Net Using Disease Categories as Direct Gap Predictors
#------------------------------------------------------------------------------------------


# The paper uses one aggregate "NCD burden" variable as a gap predictor.
# This repo's phase-2 work has the full 22-category disaggregated
# cause-specific YLD data. This script asks a question the paper's own
# aggregate variable cannot answer: which SPECIFIC diseases predict the gap
# directly, not just "noncommunicable disease burden" as a single number.
#
# This is a different question from what R/05/R/11/R/13 already asked. Those
# ask which causes separate the two disease-burden CLUSTERS from each
# other -- a question about the causes' covariance structure with each
# other. This asks which causes predict the GAP ITSELF once put in a
# regression together -- a question about each cause's relationship to the
# outcome, net of the others. Agreement or disagreement between the two is
# informative either way, not something to force into alignment.
#
# 2019 cross-section, matching the year the clustering and its validation
# checks already use. LASSO (alpha = 1) and elastic net (alpha = 0.5), both
# cross-validated for lambda. glmnet standardizes predictors internally by
# default (standardize = TRUE), so the 22 causes, measured on different
# scales, are on comparable footing before the penalty is applied.

library(dplyr)
library(tidyr)
library(glmnet)

set.seed(1)

burden <- read.csv("data_processed/disease_burden_long.csv")
dataset <- read.csv("data_processed/analysis_dataset.csv")

LASSO_YEAR <- 2019

wide_burden <- burden %>%
  filter(year == LASSO_YEAR) %>%
  select(iso3, cause_name, yld_per_1000) %>%
  pivot_wider(names_from = cause_name, values_from = yld_per_1000) %>%
  filter(if_all(-iso3, ~ !is.na(.)))

feature_matrix <- wide_burden %>% select(-iso3) %>% as.matrix()
rownames(feature_matrix) <- wide_burden$iso3

zero_var <- apply(feature_matrix, 2, function(x) isTRUE(all.equal(sd(x), 0)))
if (any(zero_var)) {
  message("Dropping zero-variance cause columns: ", paste(colnames(feature_matrix)[zero_var], collapse = ", "))
  feature_matrix <- feature_matrix[, !zero_var, drop = FALSE]
}

gap_lookup <- dataset %>% filter(year == LASSO_YEAR) %>% select(iso3, gap)

modeling_data <- data.frame(iso3 = rownames(feature_matrix), feature_matrix, check.names = FALSE) %>%
  inner_join(gap_lookup, by = "iso3") %>%
  filter(!is.na(gap))

x <- as.matrix(modeling_data %>% select(-iso3, -gap))
y <- modeling_data$gap
cause_names <- colnames(x)

## --- LASSO (alpha = 1) ------------------------------------------------------

cv_lasso <- cv.glmnet(x, y, alpha = 1, standardize = TRUE, nfolds = 10)
lasso_1se <- as.matrix(coef(cv_lasso, s = "lambda.1se"))
lasso_min <- as.matrix(coef(cv_lasso, s = "lambda.min"))

## --- Elastic net (alpha = 0.5) ----------------------------------------------

cv_enet <- cv.glmnet(x, y, alpha = 0.5, standardize = TRUE, nfolds = 10)
enet_1se <- as.matrix(coef(cv_enet, s = "lambda.1se"))
enet_min <- as.matrix(coef(cv_enet, s = "lambda.min"))

coef_table <- data.frame(
  cause = rownames(lasso_1se)[-1],  # drop intercept row
  lasso_lambda.1se = lasso_1se[-1, 1],
  lasso_lambda.min = lasso_min[-1, 1],
  enet_lambda.1se = enet_1se[-1, 1],
  enet_lambda.min = enet_min[-1, 1]
) %>%
  arrange(desc(abs(lasso_lambda.1se)))

dir.create("output/tables", showWarnings = FALSE, recursive = TRUE)
write.csv(coef_table, "output/tables/lasso_gap_predictors_coefficients.csv", row.names = FALSE)

## Cross-check against the causes R/11 (random forest) and R/13 (Boruta)
## already flagged as decisive for the disease-burden CLUSTER split, a
## different question, not something this comparison forces into agreement.
rf_importance <- tryCatch(read.csv("output/tables/cluster_rf_importance.csv"), error = function(e) NULL)
top10_rf_clustering <- if (!is.null(rf_importance)) head(rf_importance$cause, 10) else character(0)

lasso_nonzero_1se <- coef_table %>% filter(lasso_lambda.1se != 0) %>% pull(cause)
overlap_with_clustering <- intersect(lasso_nonzero_1se, top10_rf_clustering)

sink("output/tables/lasso_gap_predictors_summary.txt")
cat("LASSO / elastic net, gap ~ 22 disease-burden categories directly,", LASSO_YEAR,
    "| n countries:", nrow(modeling_data), "\n")
cat("NOT attempted by the paper -- the paper uses one aggregate NCD-burden\n")
cat("predictor; this asks which SPECIFIC causes predict the gap directly. See README.\n\n")

cat("-- Cross-validated lambda --\n")
cat("LASSO: lambda.min =", signif(cv_lasso$lambda.min, 4), ", lambda.1se =", signif(cv_lasso$lambda.1se, 4), "\n")
cat("Elastic net (alpha=0.5): lambda.min =", signif(cv_enet$lambda.min, 4),
    ", lambda.1se =", signif(cv_enet$lambda.1se, 4), "\n\n")

cat("-- LASSO coefficients at lambda.1se (the more conservative, sparser fit) --\n")
print(coef_table %>% select(cause, lasso_lambda.1se) %>% filter(lasso_lambda.1se != 0))

cat("\n-- Full coefficient table, all four fits --\n")
print(coef_table)

cat("\n-- Causes with a nonzero LASSO (lambda.1se) coefficient:", length(lasso_nonzero_1se), "of",
    length(cause_names), "--\n")
cat(paste(lasso_nonzero_1se, collapse = ", "), "\n\n")

cat("-- Overlap with the causes R/11's random forest flagged as decisive for the\n")
cat("   disease-burden CLUSTER split (a different question: separating clusters,\n")
cat("   not predicting the gap) --\n")
cat("Overlap:", length(overlap_with_clustering), "of", length(lasso_nonzero_1se),
    "LASSO-selected causes --", paste(overlap_with_clustering, collapse = ", "), "\n")
sink()

message("Wrote output/tables/lasso_gap_predictors_coefficients.csv and lasso_gap_predictors_summary.txt")
message(length(lasso_nonzero_1se), " of ", length(cause_names),
        " causes survive LASSO at lambda.1se; ", length(overlap_with_clustering),
        " overlap with the clustering's top-10 RF-important causes")
