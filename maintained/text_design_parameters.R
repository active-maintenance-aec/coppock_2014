# coppock_2014/maintained/text_design_parameters.R
# Output: maintained/output/text_design_parameters.csv
# Depends on: maintained/data/spillovers.rds, original/CoppockJEPS_rollcalldata.csv,
#             helpers.R
# Description: The design quantities the article states in prose: the size of the
#   chamber, the number of legislators treated, the number of matched pairs and the
#   number of random assignments those pairs admit, the roll call votes the ideal
#   points are estimated from, and the range of the similarity scores Equations (1)
#   and (3) produce.
#
#   These are read out of the deposit rather than asserted. The article writes the
#   number of possible random assignments twice, in two different units, so the count
#   has to come from somewhere other than the page.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data

# Roll call votes ----
# Columns 5 onwards of the deposited roll call file are the votes; the first four are
# state, district, name and party.
# The deposit heads two columns "HB 484", so the names need repairing; only the count
# of vote columns is used.
roll_calls <- read_csv(here::here("original", "CoppockJEPS_rollcalldata.csv"),
                       show_col_types = FALSE, name_repair = "unique_quiet")
n_key_votes <- ncol(roll_calls) - 4L

# Similarity scores ----
# Both formulas are evaluated on the deposited ideal points, which is what the
# appendix compares. The corrected analysis uses the corrigendum's scores, but the
# appendix's claim about the two functional forms is about the deposit's own.
scores <- dat$dwnom_scores
absolute <- similarity_from_scores(scores)
squared <- similarity_from_scores(scores, transform = function(x, y) (4 - (x - y)^2) / 4)

# Pairs where either legislator has no ideal point are zeroed by
# similarity_from_scores(), so they are excluded before the range is taken.
scored <- !is.na(scores)
distinct_pairs <- outer(scored, scored, "&") & row(absolute) != col(absolute)
excess <- squared[distinct_pairs] - absolute[distinct_pairs]

ranks <- rank(scores, na.last = "keep")

n_pairs <- n_distinct(dat$match_category)

parameters <- tibble(
  claim = c("Legislators in the chamber",
            "Legislators assigned to treatment",
            "Legislators assigned to control",
            "Matched pairs",
            "Possible matched-pair random assignments",
            "Randomizations in the deposited randomization matrix",
            "Roll call votes behind the ideal points",
            "Legislators with an ideal point",
            "Largest difference between two ideal point ranks",
            "Smallest similarity score under Equation (1)",
            "Largest similarity score under Equation (1)",
            "Smallest amount by which Equation (3) exceeds Equation (1)",
            "Legislator pairs where Equation (3) equals Equation (1)"),
  value = c(nrow(dat),
            sum(dat$treatment),
            sum(dat$treatment == 0),
            n_pairs,
            2^n_pairs,
            ncol(spillovers$z_block),
            n_key_votes,
            sum(scored),
            max(ranks, na.rm = TRUE) - min(ranks, na.rm = TRUE),
            min(absolute[distinct_pairs]),
            max(absolute[distinct_pairs]),
            min(excess),
            sum(excess == 0) / 2)
)

write_csv(parameters, here::here("maintained", "output", "text_design_parameters.csv"))
print(parameters)
