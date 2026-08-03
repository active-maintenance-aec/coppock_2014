# coppock_2014/maintained/figure_a3_squared_spillover.R
# Output: maintained/output/figure_a3_squared_spillover.csv
#         maintained/output/figure_a3_squared_spillover.pdf
#         maintained/output/figure_a3_squared_spillover.png
#         maintained/data/figure_a3.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Appendix Figure 3. p-value map for the spillover model in which ideological
#   similarity is measured by the squared distance between ideal points
#   (Equation 3 of the appendix).
#   This parameterization is unaffected by the coding error the corrigendum reports:
#   its similarity matrix is stored correctly in the deposit and rebuilds exactly.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data

fit <- pvalue_grid(
  y_obs = dat$sb24,
  z_obs = dat$treatment,
  exposure_obs = spillovers$exposure_sq$observed,
  similarity = spillovers$similarity_sq,
  expected_1 = spillovers$exposure_sq$expected_1,
  expected_0 = spillovers$exposure_sq$expected_0,
  z_block = spillovers$z_block,
  directs = seq(from = -0.7, to = 0.5, by = 0.025),
  indirects = seq(from = -0.5, to = 0.7, by = 0.025),
  sims = 500,
  seed = 343
)

write_rds(fit, here::here("maintained", "data", "figure_a3.rds"))

# The appendix says this model supports the hypothesis that both effects are zero, so
# the p-value at that cell is a published claim and belongs in the committed output.
p_at_origin <- fit$pmat[which.min(abs(fit$directs)), which.min(abs(fit$indirects))]

estimates <- tibble(
  claim = str_glue("figure_a3: {c('direct effect', 'direct 95% CI lower', 'direct 95% CI upper', 'indirect effect', 'indirect 95% CI lower', 'indirect 95% CI upper', 'p-value at the zero-zero hypothesis')}"),
  value = round(c(fit$direct_point, fit$direct_ci[1], fit$direct_ci[2],
                  fit$indirect_point, fit$indirect_ci[1], fit$indirect_ci[2],
                  p_at_origin), 6)
)

# The plotted values must land in a committed file, not only the console, or the
# ground truth's value_rewrite cannot be traced to anything.
write_csv(estimates, here::here("maintained", "output", "figure_a3_squared_spillover.csv"))
print(estimates)

# Figure ----
g <- make_pvalue_tile(tile_grid(fit)) +
  ci_arrow(x = fit$direct_ci[1], xend = fit$direct_ci[2], y = 0.6, yend = 0.6) +
  ci_arrow(x = 0.35, xend = 0.35, y = fit$indirect_ci[1], yend = fit$indirect_ci[2])

save_figure(g, "figure_a3_squared_spillover")
