# coppock_2014/maintained/figure_2_ideo_spillover.R
# Output: maintained/output/figure_2_ideo_spillover.csv
#         maintained/output/figure_2_ideo_spillover.pdf
#         maintained/output/figure_2_ideo_spillover.png
#         maintained/output/figure_2_ideo_spillover_uncorrected.pdf
#         maintained/output/figure_2_ideo_spillover_uncorrected.png
#         maintained/data/figure_2.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Figure 2, the main analysis. p-value map for the ideological similarity
#   spillover model, in two versions.
#
#   The corrected version uses the similarity matrix of Equation (1) to build the
#   simulated exposures, which is what Coppock (2016) says the published analysis
#   should have done.
#
#   The uncorrected version uses the all-ones matrix stored in the deposit, and so
#   reproduces the map printed in the 2014 article. It is here because the corrigendum
#   prints the two side by side, and because the difference between them is the finding
#   this repository exists to record. Both maps are computed; neither is transcribed.

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

write_rds(list(corrected = corrected, uncorrected = uncorrected),
          here::here("maintained", "data", "figure_2.rds"))

estimates <- tibble(
  claim = rep(c("Figure 2: direct effect", "Figure 2: direct 95% CI lower",
                "Figure 2: direct 95% CI upper", "Figure 2: indirect effect",
                "Figure 2: indirect 95% CI lower", "Figure 2: indirect 95% CI upper"), 2),
  version = rep(c("corrected", "uncorrected"), each = 6),
  value = c(corrected$direct_point, corrected$direct_ci[1], corrected$direct_ci[2],
            corrected$indirect_point, corrected$indirect_ci[1], corrected$indirect_ci[2],
            uncorrected$direct_point, uncorrected$direct_ci[1], uncorrected$direct_ci[2],
            uncorrected$indirect_point, uncorrected$indirect_ci[1], uncorrected$indirect_ci[2])
) |>
  mutate(value = round(value, 6))

# The plotted values must land in a committed file, not only the console, or the
# ground truth's value_rewrite cannot be traced to anything.
write_csv(estimates, here::here("maintained", "output", "figure_2_ideo_spillover.csv"))
print(estimates)

# Figures ----
draw_map <- function(fit) {
  make_pvalue_tile(tile_grid(fit)) +
    ci_arrow(x = fit$direct_ci[1], xend = fit$direct_ci[2], y = -0.5, yend = -0.5) +
    ci_arrow(x = -0.6, xend = -0.6, y = fit$indirect_ci[1], yend = fit$indirect_ci[2])
}

save_figure(draw_map(corrected), "figure_2_ideo_spillover")
save_figure(draw_map(uncorrected), "figure_2_ideo_spillover_uncorrected")
