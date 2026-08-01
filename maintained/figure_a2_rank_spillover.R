# coppock_2014/maintained/figure_a2_rank_spillover.R
# Output: maintained/output/figure_a2_rank_spillover.pdf
#         maintained/output/figure_a2_rank_spillover.png
#         maintained/data/figure_a2.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Appendix Figure 2. p-value map for the spillover model in which ideological
#   similarity is measured by the distance between the ranks of ideal points
#   (Equation 2 of the appendix).
#   This parameterization is unaffected by the coding error the corrigendum reports:
#   its similarity matrix is stored correctly in the deposit and rebuilds exactly.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data

fit <- pvalue_grid(
  y_obs = dat$sb24,
  z_obs = dat$treatment,
  exposure_obs = spillovers$exposure_rank$observed,
  similarity = spillovers$similarity_rank,
  expected_1 = spillovers$exposure_rank$expected_1,
  expected_0 = spillovers$exposure_rank$expected_0,
  z_block = spillovers$z_block,
  directs = seq(from = -0.5, to = 0.5, by = 0.025),
  indirects = seq(from = -0.5, to = 0.5, by = 0.025),
  sims = 500,
  seed = 343
)

write_rds(fit, here::here("maintained", "data", "figure_a2.rds"))
print(tibble(
  claim = str_glue("figure_a2: {c('direct effect', 'direct 95% CI lower', 'direct 95% CI upper', 'indirect effect', 'indirect 95% CI lower', 'indirect 95% CI upper')}"),
  value = c(fit$direct_point, fit$direct_ci[1], fit$direct_ci[2],
            fit$indirect_point, fit$indirect_ci[1], fit$indirect_ci[2])
))

# Figure ----
g <- make_pvalue_tile(tile_grid(fit)) +
  ci_arrow(x = fit$direct_ci[1], xend = fit$direct_ci[2], y = 0.25, yend = 0.25) +
  ci_arrow(x = 0.3, xend = 0.3, y = fit$indirect_ci[1], yend = fit$indirect_ci[2])

save_figure(g, "figure_a2_rank_spillover")
