# coppock_2014/maintained/figure_a5_four_parameter.R
# Output: maintained/output/figure_a5a_four_parameter_low.pdf
#         maintained/output/figure_a5a_four_parameter_low.png
#         maintained/output/figure_a5b_four_parameter_high.pdf
#         maintained/output/figure_a5b_four_parameter_high.png
#         maintained/output/figure_a5a_four_parameter_low_uncorrected.pdf
#         maintained/output/figure_a5a_four_parameter_low_uncorrected.png
#         maintained/output/figure_a5b_four_parameter_high_uncorrected.pdf
#         maintained/output/figure_a5b_four_parameter_high_uncorrected.png
#         maintained/data/figure_a5.rds
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Appendix Figure 5. The four-parameter generalization of Figure 3, in
#   which the direct and indirect effects are estimated jointly rather than by
#   subsetting, on a coarse 0.1 grid. The maps shown are the two-dimensional slices
#   through the four-dimensional p-value array at the other subgroup's point estimate,
#   which is how the appendix presents them.
#
#   Two versions, and the difference between them is larger here than anywhere else in
#   the paper. CoppockJEPS_appendixfigure5.R draws the simulated assignment as
#   Z_block[, 1] inside a loop over 50 simulations, so all fifty simulations use the
#   same assignment and every p-value in the published map is either 0 or 1. That is
#   visible in the appendix figure, whose shaded regions are solid blocks with no
#   gradation. The uncorrected version below reproduces it; the corrected version draws
#   a fresh assignment per simulation, as every other script in the archive does, and
#   uses the corrected similarity matrix.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
dat <- spillovers$data
z_block <- spillovers$z_block

z_obs <- dat$treatment
y_obs <- dat$sb24
low_support <- as.numeric(dat$lowsupport)

directs <- seq(from = -0.8, to = 0.4, by = 0.1)
indirects <- seq(from = -0.8, to = 0.4, by = 0.1)
sims <- 50
seed <- 343

design <- function(z, exposure) {
  cbind(1, z, exposure, low_support, z * low_support, exposure * low_support)
}

four_parameter_array <- function(similarity, exposure, resample) {
  exposure_obs <- exposure$observed
  ssr_obs <- ssr(y_obs, design(z_obs, exposure_obs))
  pmat <- array(NA_real_, dim = c(length(directs), length(indirects),
                                  length(directs), length(indirects)))
  set.seed(seed)
  for (j in seq_along(directs)) {
    for (k in seq_along(indirects)) {
      for (l in seq_along(directs)) {
        for (m in seq_along(indirects)) {
          direct_low <- directs[j]
          indirect_low <- indirects[k]
          direct_high <- directs[l]
          indirect_high <- indirects[m]
          ssr_sims <- numeric(sims)
          for (i in seq_len(sims)) {
            z_sim <- if (resample) z_block[, sample(ncol(z_block), 1)] else z_block[, 1]
            exposure_sim <- net_exposure(similarity, z_sim,
                                         exposure$expected_1, exposure$expected_0)
            pure_y0 <- y_obs - exposure_obs *
              if_else(low_support == 1, indirect_low, indirect_high)
            pure_y0[z_obs == 1] <- pure_y0[z_obs == 1] -
              if_else(low_support[z_obs == 1] == 1, direct_low, direct_high)
            y_sim <- pure_y0 +
              z_sim * if_else(low_support == 1, direct_low, direct_high) +
              exposure_sim * if_else(low_support == 1, indirect_low, indirect_high)
            ssr_sims[i] <- ssr(y_sim, design(z_sim, exposure_sim))
          }
          pmat[j, k, l, m] <- mean(ssr_obs > ssr_sims)
        }
      }
    }
  }
  peaks <- which(pmat == max(pmat), arr.ind = TRUE)
  point <- c(low_direct = median(directs[peaks[, 1]]),
             low_indirect = median(indirects[peaks[, 2]]),
             high_direct = median(directs[peaks[, 3]]),
             high_indirect = median(indirects[peaks[, 4]]))
  # The 95% confidence region for each parameter maximizes the p-value over the other
  # three, which is the Berger and Boos (1994) construction the original script names.
  axes <- list(directs, indirects, directs, indirects)
  interval <- map(1:4, \(d) axes[[d]][region_bounds(apply(pmat, d, max) > 0.05)])
  names(interval) <- names(point)
  # The maps are the two-dimensional slices through the array at the other subgroup's
  # point estimate, which is how the appendix presents them.
  # The point estimate is a median over the cells attaining the highest p-value, so it
  # can fall between grid points; the slice is taken at the nearest one.
  nearest <- function(axis, value) which.min(abs(axis - value))
  low_slice <- pmat[, , nearest(directs, point[["high_direct"]]),
                    nearest(indirects, point[["high_indirect"]])]
  high_slice <- pmat[nearest(directs, point[["low_direct"]]),
                     nearest(indirects, point[["low_indirect"]]), , ]
  list(
    point = point,
    interval = interval,
    low = list(pmat = low_slice, directs = directs, indirects = indirects),
    high = list(pmat = high_slice, directs = directs, indirects = indirects)
  )
}

corrected <- four_parameter_array(spillovers$similarity_dw, spillovers$exposure_dw,
                                  resample = TRUE)
uncorrected <- four_parameter_array(spillovers$similarity_dw_deposited,
                                    spillovers$exposure_dw_deposited,
                                    resample = FALSE)

write_rds(list(corrected = corrected, uncorrected = uncorrected),
          here::here("maintained", "data", "figure_a5.rds"))

summarize_version <- function(fit, version) {
  tibble(
    claim = str_glue("Appendix Figure A5: {names(fit$point)}"),
    version = version,
    value = as.numeric(fit$point),
    ci_lower = map_dbl(fit$interval, \(x) x[1]),
    ci_upper = map_dbl(fit$interval, \(x) x[2])
  )
}

# The published map takes two values because its simulation never permutes.
distinct_pvalues <- function(fit, version) {
  tibble(claim = "Appendix Figure A5: distinct p-values in the array",
         version = version,
         value = length(unique(as.vector(fit$low$pmat))),
         ci_lower = NA_real_, ci_upper = NA_real_)
}

figure_a5 <- bind_rows(
  summarize_version(corrected, "corrected"),
  summarize_version(uncorrected, "uncorrected"),
  distinct_pvalues(corrected, "corrected"),
  distinct_pvalues(uncorrected, "uncorrected")
) |>
  # Grid points such as -0.2 arrive as -0.19999999999999996 out of seq(); rounding at
  # the display step keeps that out of the CSV.
  mutate(across(c(value, ci_lower, ci_upper), \(x) round(x, 6)))

write_csv(figure_a5, here::here("maintained", "output", "figure_a5_four_parameter.csv"))
print(figure_a5, n = 10)

# Figures ----
draw_map <- function(fit, xlab, ylab) {
  make_pvalue_tile(tile_grid(fit), xlab = xlab, ylab = ylab)
}

save_figure(draw_map(corrected$low, "Hypothesized direct effect",
                     "Hypothesized indirect effect"),
            "figure_a5a_four_parameter_low")
save_figure(draw_map(corrected$high, "Hypothesized direct effect",
                     "Hypothesized indirect effect"),
            "figure_a5b_four_parameter_high")
save_figure(draw_map(uncorrected$low, "Hypothesized direct effect",
                     "Hypothesized indirect effect"),
            "figure_a5a_four_parameter_low_uncorrected")
save_figure(draw_map(uncorrected$high, "Hypothesized direct effect",
                     "Hypothesized indirect effect"),
            "figure_a5b_four_parameter_high_uncorrected")
