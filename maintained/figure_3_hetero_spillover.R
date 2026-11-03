# coppock_2014/maintained/figure_3_hetero_spillover.R
# Output: maintained/output/figure_3_hetero_spillover.csv
#         maintained/output/figure_3a_hetero_spillover_low.pdf
#         maintained/output/figure_3a_hetero_spillover_low.png
#         maintained/output/figure_3b_hetero_spillover_high.pdf
#         maintained/output/figure_3b_hetero_spillover_high.png
#         maintained/output/figure_3a_hetero_spillover_low_uncorrected.pdf
#         maintained/output/figure_3a_hetero_spillover_low_uncorrected.png
#         maintained/output/figure_3b_hetero_spillover_high_uncorrected.pdf
#         maintained/output/figure_3b_hetero_spillover_high_uncorrected.png
#         maintained/data/figure_3.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Figure 3. p-value maps for the ideological similarity spillover model
#   estimated separately among lower-support and higher-support districts. The same
#   pair of hypothesized effects is imposed on everyone; the SSR is then computed
#   within each subgroup. Corrected and uncorrected versions, for the reason given in
#   figure_2_ideo_spillover.R: the corrigendum reports that this figure carries the
#   same error as Figure 2.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data
z_block <- spillovers$z_block

z_obs <- dat$treatment
y_obs <- dat$sb24
low_support <- dat$lowsupport

directs <- seq(from = -0.9, to = 0.2, by = 0.025)
indirects <- seq(from = -0.5, to = 0.2, by = 0.025)
sims <- 500
seed <- 343

# The subgroup version of pvalue_grid: identical simulation, two test statistics.
subgroup_grids <- function(similarity, exposure) {
  exposure_obs <- exposure$observed
  ssr_obs_low <- ssr(y_obs[low_support == 1],
                     cbind(1, z_obs, exposure_obs)[low_support == 1, ])
  ssr_obs_high <- ssr(y_obs[low_support == 0],
                      cbind(1, z_obs, exposure_obs)[low_support == 0, ])
  pmat_low <- matrix(NA_real_, length(directs), length(indirects))
  pmat_high <- matrix(NA_real_, length(directs), length(indirects))
  set.seed(seed)
  for (j in seq_along(directs)) {
    for (k in seq_along(indirects)) {
      direct_sim <- directs[j]
      indirect_sim <- indirects[k]
      ssr_sims_low <- numeric(sims)
      ssr_sims_high <- numeric(sims)
      for (i in seq_len(sims)) {
        z_sim <- z_block[, sample(ncol(z_block), 1)]
        exposure_sim <- net_exposure(similarity, z_sim,
                                     exposure$expected_1, exposure$expected_0)
        pure_y0 <- y_obs - exposure_obs * indirect_sim
        pure_y0[z_obs == 1] <- pure_y0[z_obs == 1] - direct_sim
        y_sim <- pure_y0 + direct_sim * z_sim + indirect_sim * exposure_sim
        design <- cbind(1, z_sim, exposure_sim)
        ssr_sims_low[i] <- ssr(y_sim[low_support == 1], design[low_support == 1, ])
        ssr_sims_high[i] <- ssr(y_sim[low_support == 0], design[low_support == 0, ])
      }
      pmat_low[j, k] <- mean(ssr_obs_low > ssr_sims_low)
      pmat_high[j, k] <- mean(ssr_obs_high > ssr_sims_high)
    }
  }
  list(low = summarize_pvalue_grid(pmat_low, directs, indirects),
       high = summarize_pvalue_grid(pmat_high, directs, indirects))
}

corrected <- subgroup_grids(spillovers$similarity_dw, spillovers$exposure_dw)
uncorrected <- subgroup_grids(spillovers$similarity_dw_deposited,
                              spillovers$exposure_dw_deposited)

write_rds(list(corrected = corrected, uncorrected = uncorrected),
          here::here("maintained", "data", "figure_3.rds"))

# The Results section says no hypothesis with a positive direct effect receives
# positive probability in the lower-support panel, which is a claim about the part of
# the surface to the right of the zero line rather than about a point estimate.
report_panel <- function(fit, panel, version) {
  tibble(
    claim = str_glue("Figure 3 {panel}: {c('direct effect', 'direct 95% CI lower', 'direct 95% CI upper', 'indirect effect', 'indirect 95% CI lower', 'indirect 95% CI upper', 'highest p-value at a positive direct effect')}"),
    version = version,
    value = round(c(fit$direct_point, fit$direct_ci[1], fit$direct_ci[2],
                    fit$indirect_point, fit$indirect_ci[1], fit$indirect_ci[2],
                    max(fit$pmat[fit$directs > 0, ])), 6)
  )
}

estimates <- bind_rows(
  report_panel(corrected$low, "panel A (lower support)", "corrected"),
  report_panel(corrected$high, "panel B (higher support)", "corrected"),
  report_panel(uncorrected$low, "panel A (lower support)", "uncorrected"),
  report_panel(uncorrected$high, "panel B (higher support)", "uncorrected")
)

# The plotted values must land in a committed file, not only the console, or the
# ground truth's value_rewrite cannot be traced to anything.
write_csv(estimates, here::here("maintained", "output", "figure_3_hetero_spillover.csv"))
print(estimates, n = 24)

# Figures ----
draw_map <- function(fit, arrow_y, arrow_x) {
  make_pvalue_tile(tile_grid(fit)) +
    ci_arrow(x = fit$direct_ci[1], xend = fit$direct_ci[2], y = arrow_y, yend = arrow_y,
             edge = max(fit$directs)) +
    ci_arrow(x = arrow_x, xend = arrow_x, y = fit$indirect_ci[1], yend = fit$indirect_ci[2],
             edge = max(fit$indirects))
}

save_figure(draw_map(corrected$low, 0.1, -0.1), "figure_3a_hetero_spillover_low")
save_figure(draw_map(corrected$high, -0.1, -0.5), "figure_3b_hetero_spillover_high")
save_figure(draw_map(uncorrected$low, 0.1, -0.1),
            "figure_3a_hetero_spillover_low_uncorrected")
save_figure(draw_map(uncorrected$high, -0.1, -0.5),
            "figure_3b_hetero_spillover_high_uncorrected")
