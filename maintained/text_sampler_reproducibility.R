# coppock_2014/maintained/text_sampler_reproducibility.R
# Output: output/text_sampler_reproducibility.csv
# Depends on: data/spillovers.rds, helpers.R
# Description: The computational reproducibility check for Figure 2, which is a
#   question about the archive rather than about the rewrite. R 3.6.0 replaced the
#   sampler behind sample(), and each grid draws 685,000 times, so a pre-2019
#   analysis cannot be re-run faithfully under the current default. Setting
#   RNGkind(sample.kind = "Rounding") restores the sampler of the day.
#
#   Both panels of the corrigendum's Figure 1 are re-run here, because the sampler
#   matters to one and not to the other. The corrected panel needs it: two of its
#   bounds sit a grid step away under the current sampler and land exactly under this
#   one. The original panel does not: it returns the corrigendum's four bounds under
#   either sampler (under the archive's own rule for upper bounds; see below), which is what establishes that the ideal points rather than the
#   sampler are what separate the corrigendum's restatement from appendix Table 1.
#
#   The rewrite itself keeps the modern sampler: it is the code we would write now,
#   and the current sampler is the correct one. The two answers are close and the
#   difference belongs to the environment, not to either analysis.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data

directs <- seq(from = -0.7, to = 0.2, by = 0.025)
indirects <- seq(from = -0.7, to = 0.2, by = 0.025)
sims <- 500
seed <- 343

# Re-run under the sampler of 2016 ----
# on.exit is unreliable at the top level of a sourced file, and run_all.R sources this
# in the middle of a sequence, so the sampler is restored explicitly at the end.
old_kind <- RNGkind()
suppressWarnings(RNGkind(sample.kind = "Rounding"))

corrected <- pvalue_grid(
  y_obs = dat$sb24,
  z_obs = dat$treatment,
  exposure_obs = spillovers$exposure_dw$observed,
  similarity = spillovers$similarity_dw,
  expected_1 = spillovers$exposure_dw$expected_1,
  expected_0 = spillovers$exposure_dw$expected_0,
  z_block = spillovers$z_block,
  directs = directs, indirects = indirects, sims = sims, seed = seed
)

# The corrigendum's original panel is the published all-ones simulation matrix on the
# same corrected ideal points; see the header of figure_2_ideo_spillover.R.
corrigendum_original <- pvalue_grid(
  y_obs = dat$sb24,
  z_obs = dat$treatment,
  exposure_obs = spillovers$exposure_dw$observed,
  similarity = spillovers$similarity_dw_deposited,
  expected_1 = spillovers$exposure_dw$expected_1,
  expected_0 = spillovers$exposure_dw$expected_0,
  z_block = spillovers$z_block,
  directs = directs, indirects = indirects, sims = sims, seed = seed
)

# Against the values the corrigendum prints ----
# The archive located each region's edges with find_breaks(), which reports the first grid
# point OUTSIDE the region as its upper bound, one step above the last point inside that
# the rewrite reports. Whether the archive reproduces is a question about what the
# archive's own rule returns, so archive_rule applies it: the upper bounds move up one
# grid step. The corrected panel's direct region reaches 0.2, the top of the grid, so
# neither rule returns an upper bound there.
grid_step <- directs[2] - directs[1]

panel_rows <- function(fit, panel, corrigendum) {
  tibble(
    panel = panel,
    claim = c("direct effect", "direct 95% CI lower", "direct 95% CI upper",
              "indirect effect", "indirect 95% CI lower", "indirect 95% CI upper"),
    corrigendum = corrigendum,
    rounding_sampler = c(fit$direct_point, fit$direct_ci[1], fit$direct_ci[2],
                         fit$indirect_point, fit$indirect_ci[1], fit$indirect_ci[2]),
    archive_rule = rounding_sampler + if_else(str_detect(claim, "upper"), grid_step, 0)
  )
}

check <- bind_rows(
  panel_rows(corrected, "corrected", c(-0.250, -0.625, 0.175, -0.150, -0.325, 0.200)),
  panel_rows(corrigendum_original, "original",
             c(-0.300, -0.575, 0.000, -0.225, -0.325, -0.025))
) |>
  mutate(
    reproduces = !is.na(archive_rule) & abs(archive_rule - corrigendum) < 1e-9,
    # Two rows are FALSE for reasons that are not failures to reproduce, and a bare
    # logical cannot say which is which.
    note = case_when(
      reproduces ~ "",
      panel == "corrected" & claim == "direct 95% CI upper" ~
        "censored: the confidence region reaches the top of the grid, so no bound exists for either rule to return",
      panel == "original" & claim == "indirect effect" ~
        "the corrigendum names a cell of the maximum p-value plateau rather than its median; figure_2_ideo_spillover.csv records how wide that plateau is",
      .default = "does not reproduce"
    )
  )

write_csv(check, here::here("maintained", "output", "text_sampler_reproducibility.csv"))
print(check, n = nrow(check), width = 200)

# Restore the modern sampler for everything that runs after this ----
suppressWarnings(RNGkind(sample.kind = old_kind[3]))
stopifnot(RNGkind()[3] == old_kind[3])
