# coppock_2014/maintained/figure_1a_no_spillover.R
# Output: maintained/output/figure_1a_no_spillover.csv
#         maintained/output/figure_1a_no_spillover.pdf
#         maintained/output/figure_1a_no_spillover.png
#         maintained/data/figure_1a.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Figure 1a. p-value function for the constant effects model under the
#   non-interference assumption, which is the reanalysis of Butler and Nickerson
#   (2011) in the hypothesis-testing framework of Bowers, Fredrickson and
#   Panagopoulos (2013). This model has no spillover term, so the corrigendum's
#   correction to the similarity matrix does not touch it.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data
z_block <- spillovers$z_block

z_obs <- dat$treatment
y_obs <- dat$sb24
ssr_obs <- ssr(y_obs, cbind(1, z_obs))

ates <- seq(from = -0.5, to = 0.2, by = 0.01)
sims <- 100

# The original walks the first 100 columns of the randomization matrix in order rather
# than sampling from it, so this loop draws no random numbers and is unaffected by the
# change to sample() in R 3.6.
pmat <- map_dbl(ates, function(ate_sim) {
  ssr_sims <- map_dbl(seq_len(sims), function(i) {
    z_sim <- z_block[, i]
    pure_y0 <- y_obs
    pure_y0[z_obs == 1] <- pure_y0[z_obs == 1] - ate_sim
    y_sim <- pure_y0
    y_sim[z_sim == 1] <- y_sim[z_sim == 1] + ate_sim
    ssr(y_sim, cbind(1, z_sim))
  })
  mean(ssr_obs > ssr_sims)
})

fit <- list(
  pmat = pmat,
  ates = ates,
  ate_point = ates[which.max(pmat)],
  ate_ci = ates[region_bounds(pmat > 0.05)]
)
write_rds(fit, here::here("maintained", "data", "figure_1a.rds"))

# The p-value at the sharp null is the quantity the Results section describes as
# "slightly higher than 0.05", so it belongs in the committed output rather than only
# on the face of the plot.
estimates <- tibble(
  claim = c("Figure 1a: direct effect", "Figure 1a: direct 95% CI lower",
            "Figure 1a: direct 95% CI upper", "Figure 1a: p-value at the zero hypothesis"),
  value = round(c(fit$ate_point, fit$ate_ci[1], fit$ate_ci[2],
                  pmat[which.min(abs(ates))]), 6)
)

# The plotted values must land in a committed file, not only the console, or the
# ground truth's value_rewrite cannot be traced to anything.
write_csv(estimates, here::here("maintained", "output", "figure_1a_no_spillover.csv"))
print(estimates)

# Figure ----
gg_df <- tibble(ate = ates, pvalue = pmat)

g <- ggplot(gg_df, aes(x = ate, y = pvalue)) +
  # The original's filled circles (pch = 21). At size 2 the edition, which sets this
  # panel at about half its width, prints them about 1 mm across and they read as
  # diamonds; at 3.5 they read as circles (Alex, 2026-11-03).
  geom_point(aes(fill = pvalue), shape = 21, size = 3.5, colour = "black",
             show.legend = FALSE) +
  scale_fill_gradient(low = "white", high = "black", limits = c(0, 1)) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  ci_arrow(x = fit$ate_ci[1], xend = fit$ate_ci[2], y = 0.4, yend = 0.4) +
  labs(x = "Hypothesized average treatment effect", y = "p-values") +
  theme_bw()

save_figure(g, "figure_1a_no_spillover", width = 6, height = 6)
