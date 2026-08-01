# coppock_2014/maintained/figure_1b_no_spillover_hetero.R
# Output: maintained/output/figure_1b_no_spillover_hetero.pdf
#         maintained/output/figure_1b_no_spillover_hetero.png
#         maintained/data/figure_1b.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Figure 1b. p-value map for the heterogeneous effects model under the
#   non-interference assumption, with separate treatment effects for legislators from
#   higher-support and lower-support districts. No spillover term, so the corrigendum
#   does not touch it.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data
z_block <- spillovers$z_block

z_obs <- dat$treatment
y_obs <- dat$sb24
low_support <- as.numeric(dat$lowsupport)

design <- function(z) cbind(1, z, low_support, z * low_support)
ssr_obs <- ssr(y_obs, design(z_obs))

cates_high <- seq(from = -0.6, to = 0.5, by = 0.025)
cates_low <- seq(from = -0.8, to = 0.4, by = 0.025)
sims <- 100

# As in Figure 1a, the original walks the first 100 columns of the randomization matrix
# in order rather than sampling from it.
pmat <- matrix(NA_real_, length(cates_high), length(cates_low))
for (j in seq_along(cates_high)) {
  for (k in seq_along(cates_low)) {
    cate_high <- cates_high[j]
    cate_low <- cates_low[k]
    ssr_sims <- map_dbl(seq_len(sims), function(i) {
      z_sim <- z_block[, i]
      pure_y0 <- y_obs
      pure_y0[z_obs == 1 & low_support == 0] <-
        pure_y0[z_obs == 1 & low_support == 0] - cate_high
      pure_y0[z_obs == 1 & low_support == 1] <-
        pure_y0[z_obs == 1 & low_support == 1] - cate_low
      y_sim <- pure_y0
      y_sim[z_sim == 1 & low_support == 0] <-
        y_sim[z_sim == 1 & low_support == 0] + cate_high
      y_sim[z_sim == 1 & low_support == 1] <-
        y_sim[z_sim == 1 & low_support == 1] + cate_low
      ssr(y_sim, design(z_sim))
    })
    pmat[j, k] <- mean(ssr_obs > ssr_sims)
  }
}

peak <- which(pmat == max(pmat), arr.ind = TRUE)
fit <- list(
  pmat = pmat,
  cates_high = cates_high,
  cates_low = cates_low,
  high_point = median(cates_high[peak[, 1]]),
  low_point = median(cates_low[peak[, 2]]),
  high_ci = cates_high[find_breaks(apply(pmat, 1, max) > 0.05)],
  low_ci = cates_low[find_breaks(apply(pmat, 2, max) > 0.05)]
)
write_rds(fit, here::here("maintained", "data", "figure_1b.rds"))
print(tibble(
  claim = c("Figure 1b: effect in higher-support districts",
            "Figure 1b: higher-support 95% CI lower",
            "Figure 1b: higher-support 95% CI upper",
            "Figure 1b: effect in lower-support districts",
            "Figure 1b: lower-support 95% CI lower",
            "Figure 1b: lower-support 95% CI upper"),
  value = c(fit$high_point, fit$high_ci[1], fit$high_ci[2],
            fit$low_point, fit$low_ci[1], fit$low_ci[2])
))

# Figure ----
gg_df <- expand_grid(x = cates_high, y = cates_low) |>
  mutate(z = as.vector(pmat))

g <- make_pvalue_tile(
  gg_df,
  xlab = "Hypothesized effect in higher-support districts",
  ylab = "Hypothesized effect in lower-support districts"
) +
  ci_arrow(x = fit$high_ci[1], xend = fit$high_ci[2], y = 0.15, yend = 0.15) +
  ci_arrow(x = -0.35, xend = -0.35, y = fit$low_ci[1], yend = fit$low_ci[2])

save_figure(g, "figure_1b_no_spillover_hetero")
