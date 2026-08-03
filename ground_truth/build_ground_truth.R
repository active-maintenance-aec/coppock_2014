# coppock_2014/ground_truth/build_ground_truth.R
# Output: ground_truth/coppock_2014_ground_truth.csv
# Depends on: maintained/output/ (run run_all.R first),
#             ground_truth/published_claims.csv, maintained/in_text_claims.R
# Description: Assemble the ground truth table and run the coverage gate.
#
#   Every value_paper entry was read from the published article, its online appendix
#   or the 2016 corrigendum, and is used only as a comparison target; no published
#   number is an input to any computation here or anywhere in maintained/. Every
#   value_rewrite entry is read back out of maintained/output/, so the table cannot
#   drift from the pipeline.
#
#   The two instruments read different files for the same quantity wherever the
#   pipeline offers a choice. The appendix table cells and the in-text restatements of
#   them are read here from table_1_constant_effects.csv and table_2_hetero_effects.csv,
#   which the table scripts assemble from the saved fits; maintained/in_text_claims.R
#   reads the same cells from the per-figure CSVs.
#
#   value_script is empty throughout. This repository has no portable
#   extract_archive_values.R, so Stage 2's rule that the archive column be generated
#   rather than typed is unmet here, and a typed column would be worse than an empty
#   one. What the deposited scripts produce is recorded instead in the report, where
#   the rewrite's p-value surfaces are compared with the archive's cell by cell.

library(here)
library(tidyverse)

here::i_am("ground_truth/build_ground_truth.R")

out <- function(f) read_csv(here::here("maintained", "output", f), show_col_types = FALSE)

table_1 <- out("table_1_constant_effects.csv")
table_2 <- out("table_2_hetero_effects.csv")
design <- out("text_design_parameters.csv")
totals <- out("text_total_causal_effect.csv")
ideal_points <- out("figure_a1_ideal_points.csv")
four_parameter <- out("figure_a5_four_parameter.csv")
figure_1a <- out("figure_1a_no_spillover.csv")
figure_3 <- out("figure_3_hetero_spillover.csv")
figure_a2 <- out("figure_a2_rank_spillover.csv")
figure_a3 <- out("figure_a3_squared_spillover.csv")
figure_a4 <- out("figure_a4_geo_spillover.csv")

# Accessors ----
# Each asserts that its pattern identifies exactly one row, which is what stops a
# widened output file from turning a scalar into a vector and a ground truth row into
# a list column.
pick <- function(d, pattern, version = NULL) {
  rows <- d[str_detect(d$claim, fixed(pattern)), ]
  if (!is.null(version)) rows <- rows[rows$version == version, ]
  stopifnot(nrow(rows) == 1)
  rows$value
}

# cell: one cell of an appendix summary table, by row label and column.
cell <- function(tbl, quantity, column) {
  rows <- tbl[tbl$quantity == quantity, ]
  stopifnot(nrow(rows) == 1)
  as.numeric(rows[[column]])
}

# bound: one endpoint of a confidence interval cell, which the table scripts write as
# the string "[lower,upper]".
bound <- function(tbl, quantity, column, which) {
  rows <- tbl[tbl$quantity == quantity, ]
  stopifnot(nrow(rows) == 1)
  parts <- str_split_1(str_remove_all(rows[[column]], "\\[|\\]"), ",")
  stopifnot(length(parts) == 2)
  suppressWarnings(as.numeric(parts[which]))
}

n_legislators <- pick(design, "Legislators in the chamber")
n_treated <- pick(design, "Legislators assigned to treatment")
n_pairs <- pick(design, "Matched pairs")
n_assignments <- pick(design, "Possible matched-pair random assignments")
similarity_max <- pick(design, "Largest similarity score under Equation (1)")
similarity_min <- pick(design, "Smallest similarity score under Equation (1)")
excess_min <- pick(design, "Smallest amount by which Equation (3) exceeds Equation (1)")

dim_estimate <- pick(totals, "Difference-in-means estimate")
dim_votes <- pick(totals, "Implied change in votes")
total_effect <- pick(totals, "Total causal effect in votes, uncorrected")
doubling <- abs(total_effect) / abs(dim_votes)

ideal_extreme <- max(abs(c(pick(ideal_points, "minimum score"),
                           pick(ideal_points, "maximum score"))))

# The four-parameter model's own estimates, used for the appendix claim that it gives
# the same substantive results as Figure 3.
a5_point <- function(parameter) {
  four_parameter$value[four_parameter$claim == str_glue("Appendix Figure A5: {parameter}") &
                         four_parameter$version == "uncorrected"]
}
a5_points <- map_dbl(c("low_direct", "low_indirect", "high_direct", "high_indirect"), a5_point)
f3_points <- c(
  cell(table_2, "Direct Effect, Low Support", "absolute_distance_uncorrected"),
  cell(table_2, "Indirect Effect, Low Support", "absolute_distance_uncorrected"),
  cell(table_2, "Direct Effect, High Support", "absolute_distance_uncorrected"),
  cell(table_2, "Indirect Effect, High Support", "absolute_distance_uncorrected")
)

# Interval widths, for the claims about precision.
width_1 <- function(quantity, column) {
  bound(table_1, quantity, column, 2) - bound(table_1, quantity, column, 1)
}

# The article and its appendix ----
# claim_id ties a row to ground_truth/published_claims.csv. It is NA where a row
# records something the article does not state, such as what a wordless figure plots.
article_rows <- tribble(
  ~claim_id, ~table_figure, ~claim, ~paper_printed, ~value_rewrite, ~holds, ~defect_locus, ~notes,

  # Abstract
  "abstract_effect_twice", "Abstract, p. 159",
    "The total causal effect is twice as large as originally reported",
    "2", doubling, as.numeric(doubling > 1.5 & doubling < 2.5), NA, "",

  # Design quantities stated in prose
  "intro_treated", "Text, p. 160", "Legislators sent information",
    "35", n_treated, NA, NA, "",
  "intro_legislators", "Text, p. 160", "Legislators in the chamber",
    "70", n_legislators, NA, NA, "",
  "context_treated", "Text, p. 161", "Representatives sent survey estimates, restated",
    "35", n_treated, NA, NA, "",
  "context_legislators", "Text, p. 161", "State representatives, restated",
    "70", n_legislators, NA, NA, "",
  "method_treatments_introduced", "Text, p. 162",
    "Treatments introduced into the information sharing network",
    "35", n_treated, NA, NA, "",
  "method_assignments_exponent", "Text, pp. 161-162",
    "Matched pairs, the exponent in 2^35",
    "35", n_pairs, NA, NA, "",
  "method_assignments_sci", "Text, pp. 161-162",
    "Possible matched-pair random assignments, in units of 10^10",
    "3.4", n_assignments / 1e10, NA, NA, "",
  "method_assignments_trillion", "Text, p. 162",
    "The same set of random assignments, in units of 10^12",
    "30", n_assignments / 1e12, NA, "paper_internal",
    "Two sentences earlier the article writes this quantity as 3.4 x 10^10, which the deposit confirms. 2^35 is 34.4 billion, so the trillions figure is out by three orders of magnitude. The corrigendum does not touch it",
  "method_key_votes", "Text, p. 162", "Key votes behind the W-NOMINATE scores",
    "17", pick(design, "Roll call votes behind the ideal points"), NA, NA, "",
  "method_ideology_range", "Text, p. 162",
    "Every W-NOMINATE score lies between -1 and 1",
    "1", ideal_extreme, as.numeric(ideal_extreme <= 1), NA,
    "Largest ideal point in absolute value across the 68 legislators who have one",
  "method_eq1_range", "Text, p. 162", "Equation (1) varies between 0 and 1",
    "1", similarity_max, as.numeric(similarity_min >= 0 & similarity_max <= 1), NA,
    "Smallest and largest similarity score across distinct legislator pairs",
  "method_remaining_legislators", "Text, p. 163",
    "Legislators remaining once one is treated",
    "69", n_legislators - 1, NA, NA, "",
  "method_remaining_treated", "Text, p. 163",
    "Of those, the number that can still be treated",
    "34", n_treated - 1, NA, NA, "",

  # Results
  "results_f1a_point", "Text, p. 165", "Figure 1a point estimate",
    "-0.16", cell(table_1, "Direct Effect", "no_spillover"), NA, NA, "",
  "results_f1a_p_at_zero", "Text, p. 165",
    "Figure 1a p-value at the sharp null is slightly higher than 0.05",
    "0.05", pick(figure_1a, "p-value at the zero hypothesis"),
    as.numeric(pick(figure_1a, "p-value at the zero hypothesis") > 0.05), NA, "",
  "results_f1a_ci_lower", "Text, p. 165", "Figure 1a confidence region lower bound",
    "-0.34", bound(table_1, "Direct 95% CI", "no_spillover", 1), NA, NA, "",
  "results_f1a_ci_upper", "Text, p. 165", "Figure 1a confidence region upper bound",
    "0.02", bound(table_1, "Direct 95% CI", "no_spillover", 2), NA, NA, "",
  "results_f1b_high_point", "Text, p. 165",
    "Figure 1b point estimate, higher-support districts",
    "0.05", cell(table_2, "Direct Effect, High Support", "no_spillover"), NA, NA, "",
  "results_f1b_low_point", "Text, p. 165",
    "Figure 1b point estimate, lower-support districts",
    "-0.37", cell(table_2, "Direct Effect, Low Support", "no_spillover"), NA, NA,
    "Appendix Table 2 gives -0.375 for the same quantity and the pipeline reproduces it. The main text truncates where it would round, which lands exactly on the boundary at the two decimals it prints, so the row is a match rather than a disagreement",
  "results_f1b_bounded_low_only", "Text, p. 165",
    "The confidence region is bounded away from zero for the low-support districts only",
    "0", bound(table_2, "Direct 95% CI, High Support", "no_spillover", 2),
    as.numeric(bound(table_2, "Direct 95% CI, High Support", "no_spillover", 2) > 0 &
                 bound(table_2, "Direct 95% CI, Low Support", "no_spillover", 2) < 0), NA,
    "Higher-support upper bound lies above zero, lower-support upper bound below it",
  "results_f2_direct_point", "Text, p. 165", "Figure 2 direct effect",
    "-0.300", cell(table_1, "Direct Effect", "absolute_distance_uncorrected"), NA, NA, "",
  "results_f2_indirect_point", "Text, p. 165", "Figure 2 indirect effect",
    "-0.225", cell(table_1, "Indirect Effect", "absolute_distance_uncorrected"), NA, NA, "",
  "results_f2_direct_pp", "Text, p. 165",
    "Figure 2 direct effect on the percentage point scale",
    "30", abs(cell(table_1, "Direct Effect", "absolute_distance_uncorrected")) * 100, NA, NA, "",
  "results_f2_indirect_pp", "Text, p. 165",
    "Figure 2 indirect effect on the percentage point scale",
    "22.5", abs(cell(table_1, "Indirect Effect", "absolute_distance_uncorrected")) * 100,
    NA, NA, "",
  "results_f2_ci_excludes_zero", "Text, p. 165",
    "Neither Figure 2 confidence region crosses zero",
    "0", bound(table_1, "Direct 95% CI", "absolute_distance_uncorrected", 2),
    as.numeric(bound(table_1, "Direct 95% CI", "absolute_distance_uncorrected", 2) < 0 &
                 bound(table_1, "Indirect 95% CI", "absolute_distance_uncorrected", 2) < 0),
    NA, "Both upper bounds lie below zero",
  "results_f3a_direct_point", "Text, p. 166",
    "Figure 3a direct effect, lower-support districts",
    "-0.550", cell(table_2, "Direct Effect, Low Support", "absolute_distance_uncorrected"),
    NA, "archive",
    "The article describes the Hodges-Lehmann estimate, which is the median over the plateau of highest p-values. CoppockJEPS_figure3code.R instead reads the first and second entries of the plateau index matrix in column-major order. The lower-support plateau spans 77 cells, so the two readings diverge",
  "results_f3a_indirect_point", "Text, p. 166",
    "Figure 3a indirect effect, lower-support districts",
    "-0.125", cell(table_2, "Indirect Effect, Low Support", "absolute_distance_uncorrected"),
    NA, "archive",
    "Same plateau indexing defect as the direct effect above; the second entry of a column-major index matrix is a row position used to index the indirect axis",
  "results_f3a_no_positive_direct", "Text, p. 166",
    "No hypothesis with a positive direct effect receives positive probability",
    "0", pick(figure_3, "panel A (lower support): highest p-value at a positive direct effect", "uncorrected"),
    as.numeric(pick(figure_3, "panel A (lower support): highest p-value at a positive direct effect", "uncorrected") <= 0.05),
    NA,
    "The highest p-value to the right of the zero line is small but not zero, so the sentence holds at the 0.05 level the confidence regions use rather than literally",
  "results_f3a_indirect_touches_zero", "Text, p. 166",
    "The Figure 3a indirect confidence region extends up to but not across zero",
    "0", bound(table_2, "Indirect 95% CI, Low Support", "absolute_distance_uncorrected", 2),
    as.numeric(bound(table_2, "Indirect 95% CI, Low Support", "absolute_distance_uncorrected", 2) == 0),
    NA, "",
  "results_f3b_direct_point", "Text, p. 166",
    "Figure 3b direct effect, higher-support districts",
    "-0.175", cell(table_2, "Direct Effect, High Support", "absolute_distance_uncorrected"),
    NA, "archive", "Plateau indexing, as in Figure 3a",
  "results_f3b_indirect_point", "Text, p. 166",
    "Figure 3b indirect effect, higher-support districts",
    "-0.300", cell(table_2, "Indirect Effect, High Support", "absolute_distance_uncorrected"),
    NA, NA, "The higher-support plateau is a single cell, so the two readings agree here",
  "results_f3b_direct_crosses_zero", "Text, p. 166",
    "The Figure 3b direct effect cannot be distinguished from zero",
    "0", bound(table_2, "Direct 95% CI, High Support", "absolute_distance_uncorrected", 2),
    as.numeric(bound(table_2, "Direct 95% CI, High Support", "absolute_distance_uncorrected", 2) > 0),
    NA, "",
  "results_f3b_indirect_bounded_away", "Text, p. 166",
    "The Figure 3b indirect confidence region is bounded away from zero",
    "0", bound(table_2, "Indirect 95% CI, High Support", "absolute_distance_uncorrected", 2),
    as.numeric(bound(table_2, "Indirect 95% CI, High Support", "absolute_distance_uncorrected", 2) < 0),
    NA, "",
  "results_f3_low_stronger_than_high", "Text, p. 166",
    "Direct effects are stronger in low-support than in high-support districts",
    "0",
    cell(table_2, "Direct Effect, Low Support", "absolute_distance_uncorrected") -
      cell(table_2, "Direct Effect, High Support", "absolute_distance_uncorrected"),
    as.numeric(cell(table_2, "Direct Effect, Low Support", "absolute_distance_uncorrected") <
                 cell(table_2, "Direct Effect, High Support", "absolute_distance_uncorrected")),
    NA, "",

  # Conclusion
  "conclusion_treated", "Text, p. 167", "Treated legislators in the article's arithmetic",
    "35", pick(totals, "Legislators treated"), NA, NA, "",
  "conclusion_dim_estimate", "Text, p. 167",
    "Difference-in-means estimate in the article's arithmetic",
    "-0.16", dim_estimate, NA, NA, "",
  "conclusion_votes_changed", "Text, p. 167",
    "Votes the difference in means implies were changed",
    "-5.6", dim_votes, NA, NA, "",
  "conclusion_votes_spelled", "Text, p. 167",
    "The same quantity written out as five and a half votes",
    "5.5", round(abs(dim_votes) * 2) / 2,
    as.numeric(round(abs(dim_votes) * 2) / 2 == 5.5), NA, "",
  "conclusion_uniformity_yeas", "Text, p. 167",
    "Yea votes in the uniformity trial", "61",
    pick(totals, "Yea votes in the uniformity trial, uncorrected"), NA, NA,
    "The uniformity trial sums to 61.46, which the article rounds to 61",
  "conclusion_actual_yeas", "Text, p. 167", "Legislators who actually voted yea",
    "51", pick(totals, "Legislators voting yea"), NA, NA, "",
  "conclusion_total_effect", "Text, p. 167", "Total causal effect in votes",
    "10", total_effect, NA, NA,
    "The difference is 10.46, which the article rounds to 10",
  "conclusion_nearly_doubled", "Text, p. 167",
    "The magnitude of the total causal effect has nearly doubled",
    "2", doubling, as.numeric(doubling > 1.5 & doubling < 2), NA, "",

  # Online appendix, prose
  "app_eq1_score_range", "Appendix, section 1",
    "Equation (1) gives a score between zero and 1 for all legislator pairs",
    "1", similarity_max, as.numeric(similarity_min >= 0 & similarity_max <= 1), NA, "",
  "app_eq2_denominator", "Appendix, Equation (2)",
    "Largest possible difference between two ideal point ranks",
    "67", pick(design, "Largest difference between two ideal point ranks"), NA, NA, "",
  "app_a2_both_negative", "Appendix, section 1.1",
    "Both rank model point estimates are negative",
    "", max(cell(table_1, "Direct Effect", "rank_distance"),
            cell(table_1, "Indirect Effect", "rank_distance")),
    as.numeric(cell(table_1, "Direct Effect", "rank_distance") < 0 &
                 cell(table_1, "Indirect Effect", "rank_distance") < 0), NA,
    "The article states no number here; the value recorded is the less negative of the two estimates",
  "app_eq3_higher_than_eq1", "Appendix, section 1.2",
    "Equation (3) returns a higher value than Equation (1) for any pair of ideal points",
    "0", excess_min, as.numeric(excess_min >= 0), NA,
    "The excess is strictly positive for every pair whose ideal points differ and exactly zero for the one pair whose ideal points are identical, so the claim holds weakly rather than strictly",
  "app_a3_same_sign_more_uncertain", "Appendix, section 1.2",
    "The squared-distance estimates carry the same sign as the main analysis and are more uncertain",
    "", width_1("Direct 95% CI", "squared_distance") -
      width_1("Direct 95% CI", "absolute_distance_uncorrected"),
    as.numeric(sign(cell(table_1, "Direct Effect", "squared_distance")) ==
                 sign(cell(table_1, "Direct Effect", "absolute_distance_uncorrected")) &
                 width_1("Direct 95% CI", "squared_distance") >
                 width_1("Direct 95% CI", "absolute_distance_uncorrected")), NA,
    "The article states no number here; the value recorded is how much wider the squared-distance direct interval is",
  "app_a3_zero_supported", "Appendix, section 1.2",
    "The squared-distance model supports the hypothesis that both effects are zero",
    "0.05", pick(figure_a3, "p-value at the zero-zero hypothesis"),
    as.numeric(pick(figure_a3, "p-value at the zero-zero hypothesis") > 0.05), NA, "",
  "app_a4_direct_crosses_zero", "Appendix, section 1.3",
    "The geographic placebo direct confidence region crosses zero",
    "0", bound(table_1, "Direct 95% CI", "geographic_contiguity", 2),
    as.numeric(bound(table_1, "Direct 95% CI", "geographic_contiguity", 1) < 0 &
                 bound(table_1, "Direct 95% CI", "geographic_contiguity", 2) > 0), NA, "",
  "app_a4_zero_indirect_large_p", "Appendix, section 1.3",
    "Many hypotheses with a zero indirect effect get large p-values under the geographic placebo",
    "0.05", pick(figure_a4, "highest p-value at a zero indirect effect"),
    as.numeric(pick(figure_a4, "highest p-value at a zero indirect effect") > 0.05), NA, "",
  "app_four_parameters", "Appendix, section 2",
    "Parameters in the generalized causal model",
    "4", n_distinct(four_parameter$claim[str_detect(four_parameter$claim, "direct|indirect")]),
    NA, NA, "",
  "app_a5_same_results", "Appendix, section 2",
    "The four-parameter model gives the same substantive results as Figure 3",
    "", sum(sign(a5_points) == sign(f3_points)),
    as.numeric(all(sign(a5_points) == sign(f3_points))), NA,
    "The article states no number here; the value recorded is how many of the four parameters share a sign with Figure 3",
  "app_randomizations", "Appendix, section 4",
    "Matched pair randomizations the first archive script generates",
    "10000", pick(design, "Randomizations in the deposited randomization matrix"), NA, NA, ""
)

# The appendix summary tables ----
# Read cell by cell out of the two table scripts' output. Each row names the table
# row label and the column, so a mistyped label fails the accessor's assertion rather
# than silently reading the wrong cell.
table_cells <- tribble(
  ~claim_id, ~tbl, ~quantity, ~column, ~endpoint, ~paper_printed, ~defect_locus, ~notes,
  "t1_ns_direct", "1", "Direct Effect", "no_spillover", NA, "-0.16", NA, "",
  "t1_ns_direct_lo", "1", "Direct 95% CI", "no_spillover", 1L, "-0.34", NA, "",
  "t1_ns_direct_hi", "1", "Direct 95% CI", "no_spillover", 2L, "0.02", NA, "",
  "t1_ad_direct", "1", "Direct Effect", "absolute_distance_uncorrected", NA, "-0.3", NA, "",
  "t1_ad_direct_lo", "1", "Direct 95% CI", "absolute_distance_uncorrected", 1L, "-0.5", NA, "",
  "t1_ad_direct_hi", "1", "Direct 95% CI", "absolute_distance_uncorrected", 2L, "-0.075", NA, "",
  "t1_ad_indirect", "1", "Indirect Effect", "absolute_distance_uncorrected", NA, "-0.225", NA, "",
  "t1_ad_indirect_lo", "1", "Indirect 95% CI", "absolute_distance_uncorrected", 1L, "-0.3", NA, "",
  "t1_ad_indirect_hi", "1", "Indirect 95% CI", "absolute_distance_uncorrected", 2L, "-0.1", NA, "",
  "t1_rd_direct", "1", "Direct Effect", "rank_distance", NA, "-0.225", NA, "",
  "t1_rd_direct_lo", "1", "Direct 95% CI", "rank_distance", 1L, "-0.45", NA, "",
  "t1_rd_direct_hi", "1", "Direct 95% CI", "rank_distance", 2L, "0.1", NA, "",
  "t1_rd_indirect", "1", "Indirect Effect", "rank_distance", NA, "-0.2", NA, "",
  "t1_rd_indirect_lo", "1", "Indirect 95% CI", "rank_distance", 1L, "-0.325", NA, "",
  "t1_rd_indirect_hi", "1", "Indirect 95% CI", "rank_distance", 2L, "0.175", "unresolved",
    "One grid step from the published bound. The rewrite reproduces the archive's p-value surface for this figure cell for cell, and keeps the current sampler where the analysis predates R 3.6; the sampler check in text_sampler_reproducibility.csv covers Figure 2 only, so the cause is not established here",
  "t1_sd_direct", "1", "Direct Effect", "squared_distance", NA, "-0.25", NA, "",
  "t1_sd_direct_lo", "1", "Direct 95% CI", "squared_distance", 1L, "-0.525", NA, "",
  "t1_sd_direct_hi", "1", "Direct 95% CI", "squared_distance", 2L, "0.325", NA, "",
  "t1_sd_indirect", "1", "Indirect Effect", "squared_distance", NA, "-0.175", NA, "",
  "t1_sd_indirect_lo", "1", "Indirect 95% CI", "squared_distance", 1L, "-0.35", "unresolved",
    "One grid step from the published bound; see the rank distance note above",
  "t1_sd_indirect_hi", "1", "Indirect 95% CI", "squared_distance", 2L, "0.525", NA, "",
  "t1_gc_direct", "1", "Direct Effect", "geographic_contiguity", NA, "-0.15", NA, "",
  "t1_gc_direct_lo", "1", "Direct 95% CI", "geographic_contiguity", 1L, "-0.38", "archive",
    "CoppockJEPS_appendixfigure4.R is the one figure script in the deposit that never calls set.seed, so the published Appendix Figure 4 is one unlabelled draw and cannot be reproduced by anyone",
  "t1_gc_direct_hi", "1", "Direct 95% CI", "geographic_contiguity", 2L, "0.08", "archive",
    "Appendix Figure 4 is unseeded in the deposit",
  "t1_gc_indirect", "1", "Indirect Effect", "geographic_contiguity", NA, "-0.025", "archive",
    "Appendix Figure 4 is unseeded in the deposit. The estimate sits either side of zero across draws, so the published sign is a property of one draw rather than of the data",
  "t1_gc_indirect_lo", "1", "Indirect 95% CI", "geographic_contiguity", 1L, "-0.095", NA, "",
  "t1_gc_indirect_hi", "1", "Indirect 95% CI", "geographic_contiguity", 2L, "0.145", "archive",
    "Appendix Figure 4 is unseeded in the deposit",
  "t2_ns_high_direct", "2", "Direct Effect, High Support", "no_spillover", NA, "0.05", NA, "",
  "t2_ns_high_direct_lo", "2", "Direct 95% CI, High Support", "no_spillover", 1L, "-0.225", NA, "",
  "t2_ns_high_direct_hi", "2", "Direct 95% CI, High Support", "no_spillover", 2L, "0.35", NA, "",
  "t2_ns_low_direct", "2", "Direct Effect, Low Support", "no_spillover", NA, "-0.375", NA, "",
  "t2_ns_low_direct_lo", "2", "Direct 95% CI, Low Support", "no_spillover", 1L, "-0.675", NA, "",
  "t2_ns_low_direct_hi", "2", "Direct 95% CI, Low Support", "no_spillover", 2L, "-0.05", NA, "",
  "t2_ad_high_direct", "2", "Direct Effect, High Support", "absolute_distance_uncorrected", NA,
    "-0.175", "archive", "Plateau indexing in CoppockJEPS_figure3code.R",
  "t2_ad_high_direct_lo", "2", "Direct 95% CI, High Support", "absolute_distance_uncorrected", 1L,
    "-0.45", "unresolved",
    "Two grid steps from the published bound. The rewrite reproduces the archive's surface for this figure cell for cell under the current sampler; the sampler check covers Figure 2 only",
  "t2_ad_high_direct_hi", "2", "Direct 95% CI, High Support", "absolute_distance_uncorrected", 2L,
    "0.075", NA, "",
  "t2_ad_high_indirect", "2", "Indirect Effect, High Support", "absolute_distance_uncorrected", NA,
    "-0.3", NA, "",
  "t2_ad_high_indirect_lo", "2", "Indirect 95% CI, High Support", "absolute_distance_uncorrected", 1L,
    "-0.425", NA, "",
  "t2_ad_high_indirect_hi", "2", "Indirect 95% CI, High Support", "absolute_distance_uncorrected", 2L,
    "-0.175", NA, "",
  "t2_ad_low_direct", "2", "Direct Effect, Low Support", "absolute_distance_uncorrected", NA,
    "-0.55", "archive", "Plateau indexing in CoppockJEPS_figure3code.R; the lower-support plateau spans 77 cells",
  "t2_ad_low_direct_lo", "2", "Direct 95% CI, Low Support", "absolute_distance_uncorrected", 1L,
    "-0.825", "unresolved", "One grid step from the published bound; see the higher-support note above",
  "t2_ad_low_direct_hi", "2", "Direct 95% CI, Low Support", "absolute_distance_uncorrected", 2L,
    "-0.125", NA, "",
  "t2_ad_low_indirect", "2", "Indirect Effect, Low Support", "absolute_distance_uncorrected", NA,
    "-0.125", "archive", "Plateau indexing in CoppockJEPS_figure3code.R",
  "t2_ad_low_indirect_lo", "2", "Indirect 95% CI, Low Support", "absolute_distance_uncorrected", 1L,
    "-0.325", NA, "",
  "t2_ad_low_indirect_hi", "2", "Indirect 95% CI, Low Support", "absolute_distance_uncorrected", 2L,
    "0", NA, ""
)

table_rows <- table_cells |>
  mutate(
    value_rewrite = pmap_dbl(
      list(tbl, quantity, column, endpoint),
      function(tbl, quantity, column, endpoint) {
        target <- if (tbl == "1") table_1 else table_2
        if (is.na(endpoint)) cell(target, quantity, column)
        else bound(target, quantity, column, endpoint)
      }
    ),
    table_figure = str_glue("Appendix Table {tbl}"),
    claim = str_glue("{quantity}, {column}{if_else(is.na(endpoint), '', str_glue(', bound {endpoint}'))}"),
    holds = NA_real_
  ) |>
  select(claim_id, table_figure, claim, paper_printed, value_rewrite, holds,
         defect_locus, notes)

# The corrigendum ----
# Coppock (2016) prints two sets of values: the corrected estimates it substitutes,
# and a restatement of the original ones it is correcting. Both are recorded, and the
# restatement disagrees with the article it restates.
corrigendum_rows <- tribble(
  ~claim_id, ~table_figure, ~claim, ~paper_printed, ~value_rewrite, ~holds, ~defect_locus, ~notes,

  "corr_nearly_twice", "Corrigendum, p. 206",
    "The 2014 total effect was estimated to be nearly twice as large",
    "2", doubling, as.numeric(doubling > 1.5 & doubling < 2), NA, "",
  "corr_uncertainty_larger", "Corrigendum, p. 206",
    "The corrected indirect estimates carry more uncertainty",
    "", width_1("Indirect 95% CI", "absolute_distance") -
      width_1("Indirect 95% CI", "absolute_distance_uncorrected"),
    as.numeric(width_1("Indirect 95% CI", "absolute_distance") >
                 width_1("Indirect 95% CI", "absolute_distance_uncorrected")), NA,
    "The corrigendum states no number here; the value recorded is how much wider the corrected indirect interval is",

  "corr_orig_indirect_point", "figure_2 uncorrected", "indirect effect",
    "-0.225", cell(table_1, "Indirect Effect", "absolute_distance_uncorrected"), NA, NA, "",
  "corr_orig_direct_point", "figure_2 uncorrected", "direct effect",
    "-0.300", cell(table_1, "Direct Effect", "absolute_distance_uncorrected"), NA, NA, "",
  "corr_orig_indirect_ci_lower", "figure_2 uncorrected", "indirect 95% CI lower",
    "-0.325", bound(table_1, "Indirect 95% CI", "absolute_distance_uncorrected", 1), NA, NA, "",
  "corr_orig_indirect_ci_upper", "figure_2 uncorrected", "indirect 95% CI upper",
    "-0.025", bound(table_1, "Indirect 95% CI", "absolute_distance_uncorrected", 2),
    NA, "paper_internal",
    "Appendix Table 1 of the 2014 article states -0.1 and the deposited scripts produce it; the corrigendum restates it as -0.025",
  "corr_orig_direct_ci_lower", "figure_2 uncorrected", "direct 95% CI lower",
    "-0.575", bound(table_1, "Direct 95% CI", "absolute_distance_uncorrected", 1),
    NA, "paper_internal",
    "Appendix Table 1 of the 2014 article states -0.5 and the deposited scripts produce it; the corrigendum restates it as -0.575",
  "corr_orig_direct_ci_upper", "figure_2 uncorrected", "direct 95% CI upper",
    "0.000", bound(table_1, "Direct 95% CI", "absolute_distance_uncorrected", 2),
    NA, "paper_internal",
    "Appendix Table 1 of the 2014 article states -0.075 and the deposited scripts produce it; the corrigendum restates it as 0.000",

  "corr_new_indirect_point", "figure_2 corrected", "indirect effect",
    "-0.150", cell(table_1, "Indirect Effect", "absolute_distance"), NA, NA,
    "Reproduces exactly once the corrected analysis uses the Version 3 ideal points",
  "corr_new_direct_point", "figure_2 corrected", "direct effect",
    "-0.250", cell(table_1, "Direct Effect", "absolute_distance"), NA, NA,
    "Reproduces exactly once the corrected analysis uses the Version 3 ideal points",
  "corr_new_indirect_ci_lower", "figure_2 corrected", "indirect 95% CI lower",
    "-0.325", bound(table_1, "Indirect 95% CI", "absolute_distance", 1), NA, "environment",
    "One grid step from the published value. The rewrite uses the current sampler by design; under RNGkind(Rounding), the sampler of 2016, it reproduces exactly. See maintained/output/text_sampler_reproducibility.csv",
  "corr_new_indirect_ci_upper", "figure_2 corrected", "indirect 95% CI upper",
    "0.200", bound(table_1, "Indirect 95% CI", "absolute_distance", 2), NA, "environment",
    "One grid step from the published value. The rewrite uses the current sampler by design; under RNGkind(Rounding), the sampler of 2016, it reproduces exactly. See maintained/output/text_sampler_reproducibility.csv",
  "corr_new_direct_ci_lower", "figure_2 corrected", "direct 95% CI lower",
    "-0.625", bound(table_1, "Direct 95% CI", "absolute_distance", 1), NA, NA,
    "Reproduces exactly once the corrected analysis uses the Version 3 ideal points",
  "corr_new_direct_ci_upper", "figure_2 corrected", "direct 95% CI upper",
    "0.175", bound(table_1, "Direct 95% CI", "absolute_distance", 2), NA, "paper_internal",
    "Not identified: the confidence region reaches 0.2, the top of the grid, in the corrigendum's own surface as well as this one, so the published 0.175 is the last interior grid point rather than a bound the data support",

  "corr_wider_cis", "Corrigendum, pp. 206-207",
    "The corrected confidence intervals are much wider",
    "", bound(table_1, "Direct 95% CI", "absolute_distance", 1) -
      bound(table_1, "Direct 95% CI", "absolute_distance_uncorrected", 1),
    as.numeric(bound(table_1, "Direct 95% CI", "absolute_distance", 1) <
                 bound(table_1, "Direct 95% CI", "absolute_distance_uncorrected", 1)), NA,
    "The corrigendum states no number here; the value recorded is how much further down the corrected direct interval reaches",
  "corr_insufficient_evidence", "Corrigendum, p. 206",
    "There is insufficient evidence that indirect exposure altered legislator behavior",
    "", bound(table_1, "Indirect 95% CI", "absolute_distance", 2),
    as.numeric(bound(table_1, "Indirect 95% CI", "absolute_distance", 1) < 0 &
                 bound(table_1, "Indirect 95% CI", "absolute_distance", 2) > 0), NA,
    "The corrigendum states no number here; the value recorded is the corrected indirect upper bound, and the interval covers zero"
)

# Rows recording something the published documents do not state ----
# Appendix Figure 1 prints no numbers on its face, so nothing in the extraction covers
# it. What it plots is still countable.
unstated_rows <- tribble(
  ~claim_id, ~table_figure, ~claim, ~paper_printed, ~value_rewrite, ~holds, ~defect_locus, ~notes,
  NA, "Appendix Figure 1", "Ideal points the histogram plots", NA,
    pick(ideal_points, "legislators with an ideal point"), NA, NA,
    "The appendix states no count. Two of the 70 legislators cast too few votes for wnominate's minvotes threshold and have no score"
)

gt <- bind_rows(article_rows, table_rows, corrigendum_rows, unstated_rows)

# Agreement at the precision the document prints ----
# value_paper is carried as the string the document prints, because the number alone
# does not record its own precision: 0.30 and 0.3 are the same double, and reading the
# precision off the double would compare a three-decimal published value at a
# tolerance of 0.05.
printed_decimals <- function(txt) {
  if_else(str_detect(txt, "\\."), nchar(str_remove(txt, "^[^.]*\\.")), 0L)
}

# The tolerance is half a unit in the last printed digit, set clear of the
# floating-point boundary rather than on it. -0.375 against a published -0.37 differs
# by 0.005000000000000004 in double arithmetic, which an exact comparison files as a
# disagreement when the two are the same number rounded two ways.
agrees <- function(value, target_printed) {
  target <- suppressWarnings(parse_double(target_printed))
  case_when(
    is.na(value) | is.na(target) ~ NA_real_,
    abs(value - target) <= 0.5 * 10^(-printed_decimals(target_printed)) + 1e-9 ~ 1,
    .default = 0
  )
}

# Where a claim describes a shape rather than a printed number, formatting the
# evidence to the page's own precision destroys it: a distance of 0.425 printed to a
# page that says "0" reads as agreement with nothing. These claims carry their own
# precision, used by both instruments.
claim_digits <- c(
  abstract_effect_twice = 1L,
  conclusion_nearly_doubled = 1L,
  corr_nearly_twice = 1L,
  method_ideology_range = 3L,
  results_f1b_bounded_low_only = 3L,
  results_f2_ci_excludes_zero = 3L,
  results_f3a_no_positive_direct = 3L,
  results_f3a_indirect_touches_zero = 3L,
  results_f3b_direct_crosses_zero = 3L,
  results_f3b_indirect_bounded_away = 3L,
  results_f3_low_stronger_than_high = 4L,
  method_assignments_trillion = 2L,
  app_a2_both_negative = 3L,
  app_eq3_higher_than_eq1 = 6L,
  app_a3_same_sign_more_uncertain = 3L,
  app_a4_direct_crosses_zero = 3L,
  app_a5_same_results = 0L,
  corr_uncertainty_larger = 3L,
  corr_wider_cis = 3L,
  corr_insufficient_evidence = 3L
)

# The appendix tables print their cells at one, two or three decimals depending on the
# cell, and both instruments lay every cell against the page at three. Comparing them
# at the per-cell precision instead would compare -0.325 against -0.3 and report a
# disagreement between two instruments that agree exactly.
claim_digits <- c(claim_digits,
                  set_names(rep(3L, nrow(table_cells)), table_cells$claim_id))

descriptive_ids <- c(
  "abstract_effect_twice", "method_ideology_range", "method_eq1_range",
  "results_f1a_p_at_zero", "results_f1b_bounded_low_only", "results_f2_ci_excludes_zero",
  "results_f3a_no_positive_direct", "results_f3a_indirect_touches_zero",
  "results_f3b_direct_crosses_zero", "results_f3b_indirect_bounded_away",
  "results_f3_low_stronger_than_high", "conclusion_votes_spelled",
  "conclusion_nearly_doubled", "app_eq1_score_range", "app_a2_both_negative",
  "app_eq3_higher_than_eq1", "app_a3_same_sign_more_uncertain", "app_a3_zero_supported",
  "app_a4_direct_crosses_zero", "app_a4_zero_indirect_large_p", "app_a5_same_results",
  "corr_nearly_twice", "corr_uncertainty_larger", "corr_wider_cis",
  "corr_insufficient_evidence"
)

gt <- gt |>
  mutate(
    paper_id = if_else(str_starts(replace_na(claim_id, ""), "corr_"),
                       "coppock_2016", "coppock_2014"),
    claim_id = as.character(claim_id),
    claim = as.character(claim),
    table_figure = as.character(table_figure),
    notes = replace_na(notes, ""),
    # A descriptive claim has no printed value to be compared against, so its verdict
    # lives in holds and match_rewrite stays NA. Three states, not two.
    descriptive = claim_id %in% descriptive_ids,
    value_script = NA_real_,
    match = NA_real_,
    match_rewrite = if_else(descriptive, NA_real_, agrees(value_rewrite, paper_printed)),
    value_paper = paper_printed,
    adverse = (!is.na(match) & match == 0) |
      (!is.na(match_rewrite) & match_rewrite == 0) |
      (!is.na(holds) & holds == 0),
    clean = !adverse & ((!is.na(match_rewrite) & match_rewrite == 1) |
                          (!is.na(holds) & holds == 1)),
    defect_locus = case_when(
      adverse ~ replace_na(defect_locus, "unresolved"),
      clean ~ NA_character_,
      .default = defect_locus
    )
  )

# A locus is required on every row carrying an adverse verdict from either instrument,
# and a clean match carries none. A row with no verdict at all, because the pipeline
# cannot identify the quantity, may carry one: that is where the cause is recorded.
stopifnot(
  all(!is.na(gt$defect_locus[gt$adverse])),
  all(is.na(gt$defect_locus[gt$clean])),
  !any(duplicated(na.omit(gt$claim_id)))
)

# Coverage, checked against the extraction and against the second instrument ----
# published_claims.csv is the hand-reviewed extraction of every numeric token in the
# article, the online appendix and the corrigendum. value_paper is forced to character
# in every reader, here included: a column whose entries all look numeric is guessed as
# double, and that silently turns 0.300 into 0.3 and destroys the printed precision the
# comparison depends on.
claims <- read_csv(here::here("ground_truth", "published_claims.csv"),
                   col_types = cols(.default = col_character(),
                                    value_paper = col_character())) |>
  mutate(needs_block = needs_block == "TRUE")

stopifnot(!any(duplicated(claims$claim_id)))

# Every pipeline and descriptive claim needs a ground-truth row, and every
# ground-truth claim_id must name a claim the published record actually makes.
required_rows <- claims$claim_id[claims$claim_type %in% c("pipeline", "descriptive")]
stopifnot(
  length(setdiff(required_rows, gt$claim_id)) == 0,
  length(setdiff(na.omit(gt$claim_id), claims$claim_id)) == 0
)

# The extraction and the ground truth are two hand transcriptions of the same pages,
# free to drift apart, and nothing else compares them.
transcriptions <- gt |>
  inner_join(claims |> select(claim_id, extracted = value_paper), by = "claim_id") |>
  filter(!(is.na(value_paper) & is.na(extracted))) |>
  mutate(agrees = replace_na(value_paper, "") == replace_na(extracted, ""))
if (any(!transcriptions$agrees)) {
  print(transcriptions |> filter(!agrees) |> select(claim_id, value_paper, extracted), n = Inf)
}
stopifnot(all(transcriptions$agrees))

# The second instrument is read as a program, not as text: a block that errors at
# runtime, or that ends in a bare expression and therefore prints nothing under
# source(), would satisfy any check that merely looked for its claim id in the file.
# It is sourced into its own environment, because both files necessarily read the same
# outputs and name objects for what they hold.
claims_log <- capture.output(
  source(here::here("maintained", "in_text_claims.R"), local = new.env())
)

printed <- str_match(claims_log, "^CLAIM (\\S+) = (\\S+) \\|\\| (.*)$")
printed <- tibble(claim_id = printed[, 2], printed_value = printed[, 3],
                  label = printed[, 4]) |>
  filter(!is.na(claim_id))

declared <- claims$claim_id[claims$needs_block]
stopifnot(
  !any(duplicated(printed$claim_id)),
  nrow(printed) == length(declared),
  length(setdiff(declared, printed$claim_id)) == 0,
  length(setdiff(printed$claim_id, declared)) == 0
)

# Two instruments, compared value by value. build_ground_truth.R and in_text_claims.R
# reach each number by separate paths from the same outputs, so a disagreement between
# them is a finding in its own right.
cross_check <- printed |>
  inner_join(gt |> select(claim_id, value_paper, value_rewrite), by = "claim_id") |>
  mutate(
    digits = if_else(claim_id %in% names(claim_digits),
                     claim_digits[claim_id],
                     printed_decimals(replace_na(value_paper, "0"))),
    gt_printed = if_else(is.na(value_rewrite), "NA",
                         sprintf(paste0("%.", digits, "f"), value_rewrite)),
    agrees = printed_value == gt_printed
  )

if (any(!cross_check$agrees)) {
  print(cross_check |> filter(!agrees), n = Inf, width = 200)
}
stopifnot(length(setdiff(declared, cross_check$claim_id)) == 0,
          all(cross_check$agrees))

gt <- gt |>
  select(paper_id, claim_id, table_figure, claim, value_script, value_paper, match,
         value_rewrite, match_rewrite, holds, defect_locus, notes)

write_csv(gt, here::here("ground_truth", "coppock_2014_ground_truth.csv"))

print(gt |> select(claim_id, table_figure, claim, value_paper, value_rewrite,
                   match_rewrite, holds, defect_locus),
      n = nrow(gt), width = 200)
print(tibble(
  quantity = c("ground truth rows", "rewrite comparable", "rewrite matching",
               "rewrite differing", "descriptive claims", "descriptive claims holding",
               "extraction rows", "extraction rows needing a block",
               "claims printed by in_text_claims.R",
               "claims compared across the two instruments"),
  value = c(nrow(gt), sum(!is.na(gt$match_rewrite)), sum(gt$match_rewrite == 1, na.rm = TRUE),
            sum(gt$match_rewrite == 0, na.rm = TRUE),
            sum(!is.na(gt$holds)), sum(gt$holds == 1, na.rm = TRUE),
            nrow(claims), length(declared), nrow(printed), nrow(cross_check))
))
