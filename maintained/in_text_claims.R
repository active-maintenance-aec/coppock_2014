# coppock_2014/maintained/in_text_claims.R
# Output: printed CLAIM lines only; no files
# Depends on: maintained/output/, helpers.R
# Description: One block per claim the published record makes, each carrying the
#   sentence verbatim and then recomputing the number from the pipeline's committed
#   output. This is the second instrument: it never reads
#   ground_truth/coppock_2014_ground_truth.csv, it never refits anything, and it
#   reaches every quantity by its own path, so where it and build_ground_truth.R
#   disagree one of them is wrong.
#
#   The independence is real rather than nominal. build_ground_truth.R reads the two
#   appendix tables out of table_1_constant_effects.csv and table_2_hetero_effects.csv,
#   which the table scripts assemble from the saved fits; this file reads the same
#   cells out of the per-figure CSVs, which the figure scripts write directly. Two
#   writes, two reads, one comparison.
#
#   Every block prints a line of the form
#
#       CLAIM <claim_id> = <value> || <label>
#
#   which is what build_ground_truth.R parses to check coverage against
#   ground_truth/published_claims.csv.
#
#   Transcription conventions. The published PDFs render the minus sign as an en dash
#   and use curly quotation marks; both are written here as their ASCII equivalents,
#   and superscripts are written inline (2^35). Quotes are the sentences the documents
#   print today, however wrong. Where a sentence is wrong that is recorded in the
#   ground truth, never by editing the quote.
#
#   The 2014 article and its 2016 corrigendum disagree about several of these numbers.
#   Both are quoted, each under its own heading, and the disagreement is the finding.

source(here::here("maintained", "helpers.R"))

options(width = 200)

out <- function(f) read_csv(here::here("maintained", "output", f), show_col_types = FALSE)

f1a <- out("figure_1a_no_spillover.csv")
f1b <- out("figure_1b_no_spillover_hetero.csv")
f2 <- out("figure_2_ideo_spillover.csv")
f3 <- out("figure_3_hetero_spillover.csv")
a1 <- out("figure_a1_ideal_points.csv")
a2 <- out("figure_a2_rank_spillover.csv")
a3 <- out("figure_a3_squared_spillover.csv")
a4 <- out("figure_a4_geo_spillover.csv")
a5 <- out("figure_a5_four_parameter.csv")
design <- out("text_design_parameters.csv")
totals <- out("text_total_causal_effect.csv")

# claim: print one claim line in the form the coverage gate parses. digits is the
# number of decimal places the value is printed at, so a value printed here can be
# laid against the page without being rounded a second time.
claim <- function(id, value, label, digits = 0) {
  printed <- if (length(value) != 1 || is.na(value)) {
    "NA"
  } else {
    sprintf(paste0("%.", digits, "f"), value)
  }
  cat("CLAIM ", id, " = ", printed, " || ", label, "\n", sep = "")
}

# pick: one value out of an output file, by a pattern that has to identify it
# uniquely. The assertion is what stops a widened output file from turning a scalar
# into a vector and a claim into a silently empty line.
pick <- function(d, pattern, version = NULL) {
  rows <- d[str_detect(d$claim, fixed(pattern)), ]
  if (!is.null(version) && !is.na(version)) rows <- rows[rows$version == version, ]
  stopifnot(nrow(rows) == 1)
  rows$value
}

n_legislators <- pick(design, "Legislators in the chamber")
n_treated <- pick(design, "Legislators assigned to treatment")
n_pairs <- pick(design, "Matched pairs")
n_assignments <- pick(design, "Possible matched-pair random assignments")

dim_estimate <- pick(totals, "Difference-in-means estimate")
dim_votes <- pick(totals, "Implied change in votes")
total_effect <- pick(totals, "Total causal effect in votes, uncorrected")
doubling <- abs(total_effect) / abs(dim_votes)

# Abstract ----

# "The total causal effect of the experimental intervention appears to be twice as
#  large as reported originally."
claim("abstract_effect_twice", doubling,
      str_glue("spillover model's total causal effect {round(total_effect, 1)} votes against the difference in means' {round(dim_votes, 1)}"), 1)

# Introduction ----

# "Finally, consider the random assignment that did occur: 35 of 70 legislators were
#  sent information."
claim("intro_treated", n_treated, "legislators assigned to treatment in the deposit", 0)
claim("intro_legislators", n_legislators, "legislators in the deposited analysis frame", 0)

# Experimental context ----

# "Butler and Nickerson (2011) shared survey estimates of support for the rebate with
#  35 of the 70 state representatives using matched-pair randomization."
claim("context_treated", n_treated, "legislators assigned to treatment, restated", 0)
claim("context_legislators", n_legislators, "legislators in the chamber, restated", 0)

# Method ----

# "The random assignment of public opinion information to legislators introduced 35
#  treatments into the information sharing network of the New Mexico legislature."
claim("method_treatments_introduced", n_treated,
      "treatments introduced, which is the number of legislators assigned to treatment", 0)

# "The most flexible mapping would associate each of the 2^35 = 3.4 x 10^10 possible
#  random assignments with a unique potential outcome for each legislator."
claim("method_assignments_exponent", n_pairs,
      "matched pairs in the deposit, which is the exponent the article writes", 0)
claim("method_assignments_sci", n_assignments / 1e10,
      str_glue("2^{n_pairs} = {format(n_assignments, big.mark = ',', scientific = FALSE)} random assignments, in units of 10^10"), 1)

# "The most parsimonious function (that still serves a scientific purpose) would map
#  each of the 30 trillion random assignments onto just two potential outcomes for
#  each unit - a treated and an untreated potential outcome, ignoring the assignment
#  of the other units entirely."
claim("method_assignments_trillion", n_assignments / 1e12,
      str_glue("the same {format(n_assignments, big.mark = ',', scientific = FALSE)} random assignments, in units of 10^12, against the 30 trillion the sentence names"), 2)

# "The voting data are based on 17 key votes (as chosen by Vote Smart (2008)) from the
#  regular legislative session directly preceding the 2008 special session."
claim("method_key_votes", pick(design, "Roll call votes behind the ideal points"),
      "vote columns in the deposited roll call file", 0)

# "Focusing only on the first dimension, each legislator is assigned a W-NOMINATE
#  ideology score between -1 and 1."
ideal_extreme <- max(abs(c(pick(a1, "minimum score"), pick(a1, "maximum score"))))
claim("method_ideology_range", ideal_extreme,
      str_glue("largest ideal point in absolute value, from a range of {round(pick(a1, 'minimum score'), 3)} to {round(pick(a1, 'maximum score'), 3)}, so every score lies inside [-1, 1]"), 3)

# "For ideology values between -1 and 1, Equation (1) varies between 0 and 1."
claim("method_eq1_range", pick(design, "Largest similarity score under Equation (1)"),
      str_glue("largest similarity score under Equation (1); the smallest is {round(pick(design, 'Smallest similarity score under Equation (1)'), 3)}, so the scores lie inside [0, 1]"), 0)

# "Second, Raw Exposure is mechanically correlated with direct treatment: when
#  legislator i is treated, only 34 of the remaining 69 legislators can be treated,
#  resulting in a lower level of raw exposure."
claim("method_remaining_legislators", n_legislators - 1,
      "legislators other than the one being considered", 0)
claim("method_remaining_treated", n_treated - 1,
      "of those, the number that can still be assigned to treatment", 0)

# Results: replication of the original analysis ----

# "The p-value is maximized at -0.16, identical to the difference-in-means estimate."
claim("results_f1a_point", pick(f1a, "Figure 1a: direct effect"),
      "Figure 1a Hodges-Lehmann point estimate", 2)

# "A hypothesis of interest is the hypothesis that the true parameter is equal to
#  zero - the corresponding p is slightly higher than 0.05, indicating that this
#  result is not statistically significant at conventional levels."
claim("results_f1a_p_at_zero", pick(f1a, "p-value at the zero hypothesis"),
      "Figure 1a p-value at the sharp null, against the 0.05 the sentence names", 2)

# "The 95% confidence region extends from -0.34 to 0.02."
claim("results_f1a_ci_lower", pick(f1a, "Figure 1a: direct 95% CI lower"),
      "Figure 1a confidence region lower bound", 2)
claim("results_f1a_ci_upper", pick(f1a, "Figure 1a: direct 95% CI upper"),
      "Figure 1a confidence region upper bound", 2)

# "The p-value is maximized at (0.05, -0.37), the treatment effects in high-support
#  and low-support districts, respectively."
claim("results_f1b_high_point", pick(f1b, "effect, higher support"),
      "Figure 1b point estimate in higher-support districts", 2)
claim("results_f1b_low_point", pick(f1b, "effect, lower support"),
      "Figure 1b point estimate in lower-support districts, which appendix Table 2 prints as -0.375", 2)

# "As in the original analysis, the confidence region is bounded away from zero for
#  the low-support districts only."
f1b_high_upper <- pick(f1b, "higher support 95% CI upper")
f1b_low_upper <- pick(f1b, "lower support 95% CI upper")
claim("results_f1b_bounded_low_only", f1b_high_upper,
      str_glue("higher-support upper bound, which is above zero, against a lower-support upper bound of {round(f1b_low_upper, 3)}, which is below it"), 3)

# Results: ideological similarity spillover model ----

# "The highest p-value point is (-0.300, -0.225), constituting the point estimates of
#  direct and indirect effects."
f2_direct <- pick(f2, "Figure 2: direct effect", "uncorrected")
f2_indirect <- pick(f2, "Figure 2: indirect effect", "uncorrected")
claim("results_f2_direct_point", f2_direct,
      "Figure 2 direct effect under the similarity matrix the deposit stores", 3)
claim("results_f2_indirect_point", f2_indirect,
      "Figure 2 indirect effect under the similarity matrix the deposit stores", 3)

# "Legislators who received treatment letters were 30 percentage points less likely to
#  vote for the bill."
claim("results_f2_direct_pp", abs(f2_direct) * 100,
      "Figure 2 direct effect on the percentage point scale", 0)

# "Legislators who were exposed to a 1 standard deviation increase in second-hand
#  exposure were 22.5 percentage points less likely to vote yea."
claim("results_f2_indirect_pp", abs(f2_indirect) * 100,
      "Figure 2 indirect effect on the percentage point scale", 1)

# "The 95% confidence region does not cross zero for either the direct or indirect
#  effect, indicating that these results are statistically significant."
f2_direct_upper <- pick(f2, "Figure 2: direct 95% CI upper", "uncorrected")
f2_indirect_upper <- pick(f2, "Figure 2: indirect 95% CI upper", "uncorrected")
claim("results_f2_ci_excludes_zero", f2_direct_upper,
      str_glue("Figure 2 direct upper bound, with an indirect upper bound of {round(f2_indirect_upper, 3)}; both lie below zero"), 3)

# "Panel A presents a p-value map in the low-support districts. The highest p-value
#  point is (-0.550, -0.125)."
claim("results_f3a_direct_point",
      pick(f3, "panel A (lower support): direct effect", "uncorrected"),
      "Figure 3a direct effect, taken as the median over the plateau the article describes", 3)
claim("results_f3a_indirect_point",
      pick(f3, "panel A (lower support): indirect effect", "uncorrected"),
      "Figure 3a indirect effect, taken as the median over the plateau the article describes", 3)

# "The direct effect estimate in low-support districts is, as above, highly
#  statistically significant: no hypotheses in which the proposed value for the direct
#  effect is above zero receive positive probability."
claim("results_f3a_no_positive_direct",
      pick(f3, "panel A (lower support): highest p-value at a positive direct effect", "uncorrected"),
      "highest p-value anywhere to the right of the zero line in Figure 3a", 3)

# "The indirect effect appears to be statistically significant as well - the 95%
#  confidence region extends up to, but not across, the zero line."
claim("results_f3a_indirect_touches_zero",
      pick(f3, "panel A (lower support): indirect 95% CI upper", "uncorrected"),
      "Figure 3a indirect confidence region upper bound", 3)

# "In Panel B, the highest p-value point is (-0.175, -0.300)."
claim("results_f3b_direct_point",
      pick(f3, "panel B (higher support): direct effect", "uncorrected"),
      "Figure 3b direct effect, taken as the median over the plateau the article describes", 3)
claim("results_f3b_indirect_point",
      pick(f3, "panel B (higher support): indirect effect", "uncorrected"),
      "Figure 3b indirect effect, taken as the median over the plateau the article describes", 3)

# "As in the no spillovers model, the direct effect of treatment cannot be
#  distinguished from zero in the high-support districts."
claim("results_f3b_direct_crosses_zero",
      pick(f3, "panel B (higher support): direct 95% CI upper", "uncorrected"),
      "Figure 3b direct confidence region upper bound, which lies above zero", 3)

# "The indirect effect, however, is strongly negative and the 95% confidence region is
#  bounded away from zero."
claim("results_f3b_indirect_bounded_away",
      pick(f3, "panel B (higher support): indirect 95% CI upper", "uncorrected"),
      "Figure 3b indirect confidence region upper bound, which lies below zero", 3)

# "Allowing for the possibility of spillover effects does not alter the finding that
#  direct treatment effects appear to be stronger among legislators from low-support
#  districts than from high-support districts."
f3_low_direct <- pick(f3, "panel A (lower support): direct effect", "uncorrected")
f3_high_direct <- pick(f3, "panel B (higher support): direct effect", "uncorrected")
claim("results_f3_low_stronger_than_high", f3_low_direct - f3_high_direct,
      str_glue("lower-support direct effect {round(f3_low_direct, 4)} minus higher-support {round(f3_high_direct, 4)}"), 4)

# Conclusion ----

# "Using the difference-in-means estimate, the treatment letters appear to have
#  changed five and a half votes (35 x -0.16 = -5.6)."
claim("conclusion_treated", pick(totals, "Legislators treated"),
      "legislators treated, the first factor in the article's arithmetic", 0)
claim("conclusion_dim_estimate", dim_estimate,
      "difference-in-means estimate, the second factor in the article's arithmetic", 2)
claim("conclusion_votes_changed", dim_votes,
      "votes the difference in means implies were changed", 1)
claim("conclusion_votes_spelled", round(abs(dim_votes) * 2) / 2,
      str_glue("the same {round(abs(dim_votes), 2)} votes rounded to the nearest half vote"), 1)

# "The similarity network model estimates that in the absence of treatment, 61
#  legislators would have voted for the bill, whereas 51 actually did. The estimated
#  total causal effect is therefore 10 votes."
claim("conclusion_uniformity_yeas",
      pick(totals, "Yea votes in the uniformity trial, uncorrected"),
      "yea votes in the uniformity trial at the Figure 2 point estimates", 0)
claim("conclusion_actual_yeas", pick(totals, "Legislators voting yea"),
      "legislators who actually voted yea", 0)
claim("conclusion_total_effect", total_effect,
      "total causal effect in votes, the uniformity trial less the observed yeas", 0)

# "The bottom line for the substantive results of the Butler and Nickerson (2011)
#  experiment has not changed - if anything, the magnitude of the total causal effect
#  has nearly doubled."
claim("conclusion_nearly_doubled", doubling,
      str_glue("total causal effect {round(total_effect, 1)} votes against the difference in means' {round(dim_votes, 1)}"), 1)

# Online appendix, section 1: alternative specifications ----

# "This specification is useful because it generates a similarity score between zero
#  and 1 for all legislator pairs (i,j)."
claim("app_eq1_score_range", pick(design, "Largest similarity score under Equation (1)"),
      str_glue("largest similarity score across distinct legislator pairs; the smallest is {round(pick(design, 'Smallest similarity score under Equation (1)'), 3)}"), 0)

# Appendix Equation (2): "Similarity_i,j = (67 - |Rank(Ideo_i) - Rank(Ideo_j)|) / 67"
claim("app_eq2_denominator",
      pick(design, "Largest difference between two ideal point ranks"),
      str_glue("largest possible gap between two ideal point ranks, across the {pick(design, 'Legislators with an ideal point')} legislators who have a score"), 0)

# "The substantive findings when using this measure are similar to those reported in
#  the main analysis: both direct and indirect exposure to information appear to
#  decrease the probability of voting for SB24."
a2_direct <- pick(a2, "figure_a2: direct effect")
a2_indirect <- pick(a2, "figure_a2: indirect effect")
claim("app_a2_both_negative", max(a2_direct, a2_indirect),
      str_glue("the less negative of the rank model's two point estimates, direct {round(a2_direct, 3)} and indirect {round(a2_indirect, 3)}"), 3)

# "Note that for any pair of ideal points i and j, Equation 3 returns a higher value
#  than Equation 1."
claim("app_eq3_higher_than_eq1",
      pick(design, "Smallest amount by which Equation (3) exceeds Equation (1)"),
      str_glue("smallest excess of Equation (3) over Equation (1) across distinct pairs; it is attained at the {pick(design, 'Legislator pairs where Equation (3) equals Equation (1)')} pair whose two ideal points are identical, and is positive everywhere else"), 6)

# "The best guess of direct and indirect effects according to this model have the same
#  sign and similar magnitude to the results reported in the main analysis, but these
#  results are more uncertain."
a3_width <- pick(a3, "figure_a3: direct 95% CI upper") - pick(a3, "figure_a3: direct 95% CI lower")
f2_width <- f2_direct_upper - pick(f2, "Figure 2: direct 95% CI lower", "uncorrected")
claim("app_a3_same_sign_more_uncertain", a3_width - f2_width,
      str_glue("squared-distance direct interval is {round(a3_width, 3)} wide against Figure 2's {round(f2_width, 3)}, and its point estimate {round(pick(a3, 'figure_a3: direct effect'), 3)} carries the same sign"), 3)

# "According to this model, the data support many hypotheses, including the hypothesis
#  that the direct and indirect effects are both equal to zero."
claim("app_a3_zero_supported",
      pick(a3, "figure_a3: p-value at the zero-zero hypothesis"),
      "p-value at the hypothesis that both effects are zero, against the 0.05 threshold", 2)

# "This model recovers suggestive evidence of direct effects, though the 95%
#  confidence region does cross zero."
claim("app_a4_direct_crosses_zero", pick(a4, "figure_a4: direct 95% CI upper"),
      str_glue("geographic placebo direct upper bound, which lies above zero, with a lower bound of {round(pick(a4, 'figure_a4: direct 95% CI lower'), 3)}"), 3)

# "The evidence in support of spillovers across the geographic network is quite weak:
#  many hypotheses in which the indirect effects are presumed to be equal to zero are
#  given large p-values."
claim("app_a4_zero_indirect_large_p",
      pick(a4, "figure_a4: highest p-value at a zero indirect effect"),
      "highest p-value anywhere on the zero indirect effect line of the geographic map", 2)

# Online appendix, section 2: treatment effect heterogeneity ----

# "Instead of estimating direct and indirect effects separately by high and low
#  support, a four-parameter generalization of the causal model can be estimated."
a5_parameters <- n_distinct(a5$claim[str_detect(a5$claim, "direct|indirect")])
claim("app_four_parameters", a5_parameters,
      "parameters the four-parameter model estimates, counted from its output", 0)

# "Nevertheless, as can been seen by a comparison of Figure 5 below and Figure 3 in the
#  main paper, the substantive results are the same."
a5_points <- c(
  pick(a5, "Appendix Figure A5: low_direct", "uncorrected"),
  pick(a5, "Appendix Figure A5: low_indirect", "uncorrected"),
  pick(a5, "Appendix Figure A5: high_direct", "uncorrected"),
  pick(a5, "Appendix Figure A5: high_indirect", "uncorrected")
)
f3_points <- c(
  f3_low_direct,
  pick(f3, "panel A (lower support): indirect effect", "uncorrected"),
  f3_high_direct,
  pick(f3, "panel B (higher support): indirect effect", "uncorrected")
)
claim("app_a5_same_results", sum(sign(a5_points) == sign(f3_points)),
      str_glue("of the four parameters, the number whose sign matches Figure 3; the largest gap between the two sets is {round(max(abs(a5_points - f3_points)), 3)}"), 0)

# Online appendix, Tables 1 and 2 ----
# Float cells, so no verbatim quote: the tables print a grid of numbers rather than
# sentences. Each cell is read from the figure script's own CSV, which is a different
# file from the one build_ground_truth.R reads for the same cell.

table_cells <- tribble(
  ~claim_id, ~source, ~pattern, ~version, ~label,
  "t1_ns_direct",        "f1a", "Figure 1a: direct effect",             NA, "Table 1 no spillover, direct effect",
  "t1_ns_direct_lo",     "f1a", "Figure 1a: direct 95% CI lower",       NA, "Table 1 no spillover, direct lower bound",
  "t1_ns_direct_hi",     "f1a", "Figure 1a: direct 95% CI upper",       NA, "Table 1 no spillover, direct upper bound",
  "t1_ad_direct",        "f2",  "Figure 2: direct effect",              "uncorrected", "Table 1 absolute distance, direct effect",
  "t1_ad_direct_lo",     "f2",  "Figure 2: direct 95% CI lower",        "uncorrected", "Table 1 absolute distance, direct lower bound",
  "t1_ad_direct_hi",     "f2",  "Figure 2: direct 95% CI upper",        "uncorrected", "Table 1 absolute distance, direct upper bound",
  "t1_ad_indirect",      "f2",  "Figure 2: indirect effect",            "uncorrected", "Table 1 absolute distance, indirect effect",
  "t1_ad_indirect_lo",   "f2",  "Figure 2: indirect 95% CI lower",      "uncorrected", "Table 1 absolute distance, indirect lower bound",
  "t1_ad_indirect_hi",   "f2",  "Figure 2: indirect 95% CI upper",      "uncorrected", "Table 1 absolute distance, indirect upper bound",
  "t1_rd_direct",        "a2",  "figure_a2: direct effect",             NA, "Table 1 rank distance, direct effect",
  "t1_rd_direct_lo",     "a2",  "figure_a2: direct 95% CI lower",       NA, "Table 1 rank distance, direct lower bound",
  "t1_rd_direct_hi",     "a2",  "figure_a2: direct 95% CI upper",       NA, "Table 1 rank distance, direct upper bound",
  "t1_rd_indirect",      "a2",  "figure_a2: indirect effect",           NA, "Table 1 rank distance, indirect effect",
  "t1_rd_indirect_lo",   "a2",  "figure_a2: indirect 95% CI lower",     NA, "Table 1 rank distance, indirect lower bound",
  "t1_rd_indirect_hi",   "a2",  "figure_a2: indirect 95% CI upper",     NA, "Table 1 rank distance, indirect upper bound",
  "t1_sd_direct",        "a3",  "figure_a3: direct effect",             NA, "Table 1 squared distance, direct effect",
  "t1_sd_direct_lo",     "a3",  "figure_a3: direct 95% CI lower",       NA, "Table 1 squared distance, direct lower bound",
  "t1_sd_direct_hi",     "a3",  "figure_a3: direct 95% CI upper",       NA, "Table 1 squared distance, direct upper bound",
  "t1_sd_indirect",      "a3",  "figure_a3: indirect effect",           NA, "Table 1 squared distance, indirect effect",
  "t1_sd_indirect_lo",   "a3",  "figure_a3: indirect 95% CI lower",     NA, "Table 1 squared distance, indirect lower bound",
  "t1_sd_indirect_hi",   "a3",  "figure_a3: indirect 95% CI upper",     NA, "Table 1 squared distance, indirect upper bound",
  "t1_gc_direct",        "a4",  "figure_a4: direct effect",             NA, "Table 1 geographic contiguity, direct effect",
  "t1_gc_direct_lo",     "a4",  "figure_a4: direct 95% CI lower",       NA, "Table 1 geographic contiguity, direct lower bound",
  "t1_gc_direct_hi",     "a4",  "figure_a4: direct 95% CI upper",       NA, "Table 1 geographic contiguity, direct upper bound",
  "t1_gc_indirect",      "a4",  "figure_a4: indirect effect",           NA, "Table 1 geographic contiguity, indirect effect",
  "t1_gc_indirect_lo",   "a4",  "figure_a4: indirect 95% CI lower",     NA, "Table 1 geographic contiguity, indirect lower bound",
  "t1_gc_indirect_hi",   "a4",  "figure_a4: indirect 95% CI upper",     NA, "Table 1 geographic contiguity, indirect upper bound",
  "t2_ns_high_direct",   "f1b", "effect, higher support",               NA, "Table 2 no spillover, high support direct effect",
  "t2_ns_high_direct_lo","f1b", "higher support 95% CI lower",          NA, "Table 2 no spillover, high support lower bound",
  "t2_ns_high_direct_hi","f1b", "higher support 95% CI upper",          NA, "Table 2 no spillover, high support upper bound",
  "t2_ns_low_direct",    "f1b", "effect, lower support",                NA, "Table 2 no spillover, low support direct effect",
  "t2_ns_low_direct_lo", "f1b", "lower support 95% CI lower",           NA, "Table 2 no spillover, low support lower bound",
  "t2_ns_low_direct_hi", "f1b", "lower support 95% CI upper",           NA, "Table 2 no spillover, low support upper bound",
  "t2_ad_high_direct",   "f3",  "panel B (higher support): direct effect",         "uncorrected", "Table 2 absolute distance, high support direct effect",
  "t2_ad_high_direct_lo","f3",  "panel B (higher support): direct 95% CI lower",   "uncorrected", "Table 2 absolute distance, high support direct lower bound",
  "t2_ad_high_direct_hi","f3",  "panel B (higher support): direct 95% CI upper",   "uncorrected", "Table 2 absolute distance, high support direct upper bound",
  "t2_ad_high_indirect", "f3",  "panel B (higher support): indirect effect",       "uncorrected", "Table 2 absolute distance, high support indirect effect",
  "t2_ad_high_indirect_lo","f3","panel B (higher support): indirect 95% CI lower", "uncorrected", "Table 2 absolute distance, high support indirect lower bound",
  "t2_ad_high_indirect_hi","f3","panel B (higher support): indirect 95% CI upper", "uncorrected", "Table 2 absolute distance, high support indirect upper bound",
  "t2_ad_low_direct",    "f3",  "panel A (lower support): direct effect",          "uncorrected", "Table 2 absolute distance, low support direct effect",
  "t2_ad_low_direct_lo", "f3",  "panel A (lower support): direct 95% CI lower",    "uncorrected", "Table 2 absolute distance, low support direct lower bound",
  "t2_ad_low_direct_hi", "f3",  "panel A (lower support): direct 95% CI upper",    "uncorrected", "Table 2 absolute distance, low support direct upper bound",
  "t2_ad_low_indirect",  "f3",  "panel A (lower support): indirect effect",        "uncorrected", "Table 2 absolute distance, low support indirect effect",
  "t2_ad_low_indirect_lo","f3", "panel A (lower support): indirect 95% CI lower",  "uncorrected", "Table 2 absolute distance, low support indirect lower bound",
  "t2_ad_low_indirect_hi","f3", "panel A (lower support): indirect 95% CI upper",  "uncorrected", "Table 2 absolute distance, low support indirect upper bound"
)

sources <- list(f1a = f1a, f1b = f1b, f2 = f2, f3 = f3, a2 = a2, a3 = a3, a4 = a4)

# Appendix Table 1 prints its cells at up to three decimals and Table 2 at up to
# three, so every cell is laid against the page at three.
pwalk(table_cells, function(claim_id, source, pattern, version, label) {
  claim(claim_id, pick(sources[[source]], pattern, version), label, 3)
})

# Online appendix, section 4: replication materials ----

# "This file generates 10,000 matched pair randomizations for use in simulations."
claim("app_randomizations",
      pick(design, "Randomizations in the deposited randomization matrix"),
      "columns of the deposited randomization matrix", 0)

# Corrigendum ----
# Coppock (2016), Journal of Experimental Political Science 3(2): 206-208. The
# corrigendum restates the original estimates and prints corrected ones; both sets are
# quoted here, and the rewrite reproduces the corrected surface.

# "The reanalysis employed a method introduced by Bowers et al. (2013) to conclude that
#  the Butler and Nickerson estimate of the total effect of treatment was biased
#  downward; when spillovers were accounted for, the total effect of treatment was
#  estimated to be nearly twice as large."
claim("corr_nearly_twice", doubling,
      "the 2014 article's total causal effect against its difference in means, as the corrigendum characterizes it", 1)

# "When corrected, the uncertainty attending to the estimates of the indirect effects
#  of information as transmitted via the Ideological Similarity spillover model is
#  larger."
corrected_indirect_width <-
  pick(f2, "Figure 2: indirect 95% CI upper", "corrected") -
  pick(f2, "Figure 2: indirect 95% CI lower", "corrected")
original_indirect_width <-
  pick(f2, "Figure 2: indirect 95% CI upper", "corrigendum_original") -
  pick(f2, "Figure 2: indirect 95% CI lower", "corrigendum_original")
claim("corr_uncertainty_larger", corrected_indirect_width - original_indirect_width,
      str_glue("the corrected indirect interval is {round(corrected_indirect_width, 3)} wide against the {round(original_indirect_width, 3)} of the corrigendum's own original panel"), 3)

# "The original map led to the incorrect conclusion that the highest p-value treatment
#  effect pair was -0.225 for the indirect effect and -0.300 for the direct effect."
#
# The pair is the article's, and the article's surface returns it as the median over
# its plateau, so these two are laid against that surface. It also attains the highest
# p-value on the corrigendum's redrawn original panel, which
# figure_2_ideo_spillover.csv records alongside the size of the plateau there.
claim("corr_orig_indirect_point", f2_indirect,
      "indirect effect on the article's surface", 3)
claim("corr_orig_direct_point", f2_direct,
      "direct effect on the article's surface", 3)

# "This pair of treatment effects was relatively precisely estimated, with 95%
#  confidence intervals extending from -0.325 to -0.025 for the indirect effect and
#  -0.575 to 0.000 for the direct effect."
#
# These four are laid against the corrigendum's own original panel, which is the
# published analysis re-run on the ideal points of the archive it was computed in. The
# article's surface gives a narrower interval, and the appendix prints that one.
claim("corr_orig_indirect_ci_lower",
      pick(f2, "Figure 2: indirect 95% CI lower", "corrigendum_original"),
      "indirect lower bound on the corrigendum's original panel; appendix Table 1 of the article gives -0.3", 3)
claim("corr_orig_indirect_ci_upper",
      pick(f2, "Figure 2: indirect 95% CI upper", "corrigendum_original"),
      "indirect upper bound on the corrigendum's original panel; appendix Table 1 of the article gives -0.1", 3)
claim("corr_orig_direct_ci_lower",
      pick(f2, "Figure 2: direct 95% CI lower", "corrigendum_original"),
      "direct lower bound on the corrigendum's original panel; appendix Table 1 of the article gives -0.5", 3)
claim("corr_orig_direct_ci_upper",
      pick(f2, "Figure 2: direct 95% CI upper", "corrigendum_original"),
      "direct upper bound on the corrigendum's original panel; appendix Table 1 of the article gives -0.075", 3)

# "Instead, the highest p-value pair is -0.150 for the indirect effect and -0.250 for
#  the direct effect. The 95% confidence intervals are much wider, at [-0.325, 0.200]
#  for the indirect effect and [-0.625, 0.175] for the direct effect."
claim("corr_new_indirect_point", pick(f2, "Figure 2: indirect effect", "corrected"),
      "indirect effect under the rebuilt similarity matrix", 3)
claim("corr_new_direct_point", pick(f2, "Figure 2: direct effect", "corrected"),
      "direct effect under the rebuilt similarity matrix", 3)
claim("corr_new_indirect_ci_lower",
      pick(f2, "Figure 2: indirect 95% CI lower", "corrected"),
      "corrected indirect lower bound", 3)
claim("corr_new_indirect_ci_upper",
      pick(f2, "Figure 2: indirect 95% CI upper", "corrected"),
      "corrected indirect upper bound", 3)
claim("corr_new_direct_ci_lower",
      pick(f2, "Figure 2: direct 95% CI lower", "corrected"),
      "corrected direct lower bound", 3)
claim("corr_new_direct_ci_upper",
      pick(f2, "Figure 2: direct 95% CI upper", "corrected"),
      "corrected direct upper bound; the confidence region reaches the top of the grid, so no interior bound exists", 3)

claim("corr_wider_cis",
      pick(f2, "Figure 2: direct 95% CI lower", "corrected") -
        pick(f2, "Figure 2: direct 95% CI lower", "corrigendum_original"),
      "how much further down the corrected direct interval reaches than the one on the corrigendum's own original panel", 3)

# "There is insufficient statistical evidence to conclude that indirect exposure to
#  information altered legislator behavior."
claim("corr_insufficient_evidence",
      pick(f2, "Figure 2: indirect 95% CI upper", "corrected"),
      "corrected indirect upper bound, which lies above zero, so the interval covers no effect", 3)
