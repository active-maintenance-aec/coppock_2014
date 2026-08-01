# coppock_2014/maintained/figure_a4_geo_spillover.R
# Output: maintained/output/figure_a4_geo_spillover.csv
#         maintained/output/figure_a4_geo_spillover.pdf
#         maintained/output/figure_a4_geo_spillover.png
#         maintained/data/figure_a4.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Appendix Figure 4. p-value map for the placebo spillover model in which the
#   information network is the geographic contiguity of legislative districts.
#   This parameterization is unaffected by the coding error the corrigendum reports:
#   its similarity matrix is stored correctly in the deposit and rebuilds exactly.
#
#   CoppockJEPS_appendixfigure4.R is the one figure script in the archive that never
#   calls set.seed, so the published map cannot be reproduced by anyone, including its
#   author. This script seeds at 343, which is what every other script in the archive
#   uses, and the resulting estimates therefore differ from the printed ones.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data

fit <- pvalue_grid(
  y_obs = dat$sb24,
  z_obs = dat$treatment,
  exposure_obs = spillovers$exposure_geo$observed,
  similarity = spillovers$similarity_geo,
  expected_1 = spillovers$exposure_geo$expected_1,
  expected_0 = spillovers$exposure_geo$expected_0,
  z_block = spillovers$z_block,
  directs = seq(from = -0.5, to = 0.2, by = 0.01),
  indirects = seq(from = -0.2, to = 0.2, by = 0.005),
  sims = 500,
  seed = 343
)

write_rds(fit, here::here("maintained", "data", "figure_a4.rds"))
estimates <- tibble(
  claim = str_glue("figure_a4: {c('direct effect', 'direct 95% CI lower', 'direct 95% CI upper', 'indirect effect', 'indirect 95% CI lower', 'indirect 95% CI upper')}"),
  value = round(c(fit$direct_point, fit$direct_ci[1], fit$direct_ci[2],
                  fit$indirect_point, fit$indirect_ci[1], fit$indirect_ci[2]), 6)
)

# The plotted values must land in a committed file, not only the console, or the
# ground truth's value_rewrite cannot be traced to anything.
write_csv(estimates, here::here("maintained", "output", "figure_a4_geo_spillover.csv"))
print(estimates)

# Figure ----
g <- make_pvalue_tile(tile_grid(fit)) +
  ci_arrow(x = fit$direct_ci[1], xend = fit$direct_ci[2], y = -0.15, yend = -0.15) +
  ci_arrow(x = 0.15, xend = 0.15, y = fit$indirect_ci[1], yend = fit$indirect_ci[2])

save_figure(g, "figure_a4_geo_spillover")
