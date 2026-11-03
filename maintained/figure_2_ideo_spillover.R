# coppock_2014/maintained/figure_2_ideo_spillover.R
# Output: maintained/output/figure_2_ideo_spillover.csv
#         maintained/output/figure_2_ideo_spillover.pdf
#         maintained/output/figure_2_ideo_spillover.png
#         maintained/output/figure_2_ideo_spillover_uncorrected.pdf
#         maintained/output/figure_2_ideo_spillover_uncorrected.png
#         maintained/data/figure_2.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Output: maintained/output/figure_2_ideo_spillover_corrigendum_original.pdf
#         maintained/output/figure_2_ideo_spillover_corrigendum_original.png
# Description: Figure 2, the main analysis. p-value map for the ideological similarity
#   spillover model, in three versions.
#
#   The corrected version uses the similarity matrix of Equation (1) to build the
#   simulated exposures, which is what Coppock (2016) says the published analysis
#   should have done. It is the corrigendum's "Corrected" panel.
#
#   The uncorrected version uses the all-ones matrix stored in the deposit together
#   with the deposited exposures, and so reproduces the map printed in the 2014
#   article.
#
#   The corrigendum's own "Original" panel is a third surface, and it is not the
#   article's. Under the all-ones matrix every unit's raw exposure is the number of
#   treated colleagues, the same for everyone, so the simulated exposure varies only
#   through the expected-exposure term of Equation (5), which is built from the ideal
#   points. The uncorrected analysis therefore moves with the ideal points, and the
#   corrigendum redrew it in the working archive whose scores differ from the deposit's.
#   That surface, not the article's, is what its restated confidence intervals describe.
#
#   All three maps are computed; none is transcribed.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data
z_block <- spillovers$z_block

z_obs <- dat$treatment
y_obs <- dat$sb24

directs <- seq(from = -0.7, to = 0.2, by = 0.025)
indirects <- seq(from = -0.7, to = 0.2, by = 0.025)
sims <- 500
seed <- 343

# Corrected ----
corrected <- pvalue_grid(
  y_obs = y_obs,
  z_obs = z_obs,
  exposure_obs = spillovers$exposure_dw$observed,
  similarity = spillovers$similarity_dw,
  expected_1 = spillovers$exposure_dw$expected_1,
  expected_0 = spillovers$exposure_dw$expected_0,
  z_block = z_block,
  directs = directs, indirects = indirects, sims = sims, seed = seed
)

# Uncorrected ----
# The published analysis regressed on the correctly built net exposure but simulated
# with the all-ones matrix. Both come from exposure_dw_deposited, which is why this
# call and the one above differ only in the similarity argument.
uncorrected <- pvalue_grid(
  y_obs = y_obs,
  z_obs = z_obs,
  exposure_obs = spillovers$exposure_dw_deposited$observed,
  similarity = spillovers$similarity_dw_deposited,
  expected_1 = spillovers$exposure_dw_deposited$expected_1,
  expected_0 = spillovers$exposure_dw_deposited$expected_0,
  z_block = z_block,
  directs = directs, indirects = indirects, sims = sims, seed = seed
)

# The corrigendum's original panel ----
# The all-ones simulation matrix of the published analysis, run on the ideal points of
# the archive the corrigendum was computed in. Differs from the call above in the
# exposures only.
corrigendum_original <- pvalue_grid(
  y_obs = y_obs,
  z_obs = z_obs,
  exposure_obs = spillovers$exposure_dw$observed,
  similarity = spillovers$similarity_dw_deposited,
  expected_1 = spillovers$exposure_dw$expected_1,
  expected_0 = spillovers$exposure_dw$expected_0,
  z_block = z_block,
  directs = directs, indirects = indirects, sims = sims, seed = seed
)

write_rds(list(corrected = corrected, uncorrected = uncorrected,
               corrigendum_original = corrigendum_original),
          here::here("maintained", "data", "figure_2.rds"))

# The Hodges-Lehmann estimate is the median of the cells attaining the highest
# p-value, and how many cells that is decides how much a median can be read into. The
# count is written out because the corrigendum names a pair the median does not
# return, and a plateau of 90 cells is the reason.
plateau_cells <- function(fit) sum(fit$pmat == max(fit$pmat))

# The p-value that the corrigendum's own surface assigns to the pair the 2014 surface
# estimates. The query point comes from the pipeline, never from either document.
p_at <- function(fit, direct, indirect) {
  fit$pmat[which.min(abs(fit$directs - direct)), which.min(abs(fit$indirects - indirect))]
}

version_rows <- function(fit, version) {
  tibble(
    claim = c("Figure 2: direct effect", "Figure 2: direct 95% CI lower",
              "Figure 2: direct 95% CI upper", "Figure 2: indirect effect",
              "Figure 2: indirect 95% CI lower", "Figure 2: indirect 95% CI upper",
              "Figure 2: cells attaining the highest p-value"),
    version = version,
    value = c(fit$direct_point, fit$direct_ci[1], fit$direct_ci[2],
              fit$indirect_point, fit$indirect_ci[1], fit$indirect_ci[2],
              plateau_cells(fit))
  )
}

estimates <- bind_rows(
  version_rows(corrected, "corrected"),
  version_rows(uncorrected, "uncorrected"),
  version_rows(corrigendum_original, "corrigendum_original"),
  tibble(claim = "Figure 2: p-value at the uncorrected pair",
         version = "corrigendum_original",
         value = p_at(corrigendum_original, uncorrected$direct_point,
                      uncorrected$indirect_point))
) |>
  mutate(value = round(value, 6))

# The plotted values must land in a committed file, not only the console, or the
# ground truth's value_rewrite cannot be traced to anything.
write_csv(estimates, here::here("maintained", "output", "figure_2_ideo_spillover.csv"))
print(estimates, n = nrow(estimates))

# Figures ----
draw_map <- function(fit) {
  make_pvalue_tile(tile_grid(fit)) +
    ci_arrow(x = fit$direct_ci[1], xend = fit$direct_ci[2], y = -0.5, yend = -0.5,
             edge = max(fit$directs)) +
    ci_arrow(x = -0.6, xend = -0.6, y = fit$indirect_ci[1], yend = fit$indirect_ci[2],
             edge = max(fit$indirects))
}

save_figure(draw_map(corrected), "figure_2_ideo_spillover")
save_figure(draw_map(uncorrected), "figure_2_ideo_spillover_uncorrected")
save_figure(draw_map(corrigendum_original), "figure_2_ideo_spillover_corrigendum_original")
