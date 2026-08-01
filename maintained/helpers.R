# coppock_2014/maintained/helpers.R
# Output: none
# Depends on: nothing
# Description: Packages and shared helpers for every script in maintained/.

library(here)
library(tidyverse)
library(sf)
library(spdep)

# ssr ----
# Sum of squared residuals from an OLS fit of y on the design matrix X, dropping
# rows where y is missing. This is the test statistic of Bowers, Fredrickson and
# Panagopoulos (2013), computed several hundred thousand times per figure, so it
# goes through .lm.fit rather than lm. The two agree to floating point.
ssr <- function(y, X) {
  observed <- !is.na(y)
  sum(.lm.fit(X[observed, , drop = FALSE], y[observed])$residuals^2)
}

# find_breaks ----
# Indices at which a logical vector changes value. Used on the "some hypothesis
# in this row or column has p > 0.05" indicator to locate the edges of the 95%
# confidence region.
find_breaks <- function(x) {
  breaks <- rep(NA, length(x))
  for (i in seq_len(length(x) - 1)) {
    breaks[i + 1] <- x[i] != x[i + 1]
  }
  which(breaks)
}

# similarity_from_scores ----
# Equation (1) of the paper: Similarity_ij = (2 - |Ideo_i - Ideo_j|) / 2, with a
# zero diagonal and zeroes wherever an ideal point is missing. The `transform`
# argument gives the appendix parameterizations the same treatment.
similarity_from_scores <- function(scores, transform = function(x, y) (2 - abs(x - y)) / 2) {
  similarity <- outer(scores, scores, transform)
  diag(similarity) <- 0
  similarity[is.na(similarity)] <- 0
  similarity
}

# expected_exposure ----
# Equations (3) and (4): average exposure across the randomizations in which unit i
# is treated, and across those in which it is not.
expected_exposure <- function(similarity, z_block) {
  exposure_block <- similarity %*% z_block
  tibble(
    expected_1 = map_dbl(seq_len(nrow(exposure_block)),
                         \(i) mean(exposure_block[i, z_block[i, ] == 1])),
    expected_0 = map_dbl(seq_len(nrow(exposure_block)),
                         \(i) mean(exposure_block[i, z_block[i, ] == 0]))
  )
}

# net_exposure ----
# Equations (2) and (5): raw exposure under assignment z, minus the expected exposure
# for the arm each unit landed in, standardized. expected_1 and expected_0 are supplied
# rather than recomputed so that the caller decides which similarity matrix they
# came from.
net_exposure <- function(similarity, z, expected_1, expected_0) {
  raw <- as.vector(similarity %*% z)
  corrected <- raw - (z * expected_1 + (1 - z) * expected_0)
  as.vector((corrected - mean(corrected)) / sd(corrected))
}

# summarize_pvalue_grid ----
# Hodges-Lehmann point estimate (the median of the cells attaining the highest
# p-value) and the 95% confidence region (the extent of the rows and columns
# containing any hypothesis with p > 0.05).
#
# The median is the reading CoppockJEPS_figure2code.R uses. Every other archive script
# that draws a two-dimensional map instead writes which(pmat == max(pmat), arr.ind =
# TRUE)[1] and [2], which picks the first and second entries of the plateau index matrix
# in column-major order and, in the [2] case, uses a row position to index the column
# axis. Where the plateau is a single cell the two agree; where it is not, they do not.
# See the errata section of the report.
summarize_pvalue_grid <- function(pmat, directs, indirects) {
  peak <- which(pmat == max(pmat), arr.ind = TRUE)
  list(
    pmat = pmat,
    directs = directs,
    indirects = indirects,
    direct_point = median(directs[peak[, 1]]),
    indirect_point = median(indirects[peak[, 2]]),
    direct_ci = directs[find_breaks(apply(pmat, 1, max) > 0.05)],
    indirect_ci = indirects[find_breaks(apply(pmat, 2, max) > 0.05)]
  )
}

# pvalue_grid ----
# The constant effects spillover test behind Figures 2, A2, A3 and A4. For each pair
# of hypothesized direct and indirect effects, back out the uniformity trial of
# Equation (6), re-impose the hypothesis under `sims` draws from the set of admissible
# randomizations, and record the share of draws whose SSR the observed SSR exceeds.
#
# Every ingredient is an argument. `similarity`, `expected_1` and `expected_0` decide
# what the simulated exposure looks like; `exposure_obs` decides what the observed
# regressor is. Coppock (2014) and its corrigendum differ in exactly the first of
# these, so that choice stays visible at the call site.
pvalue_grid <- function(y_obs, z_obs, exposure_obs, similarity, expected_1, expected_0,
                        z_block, directs, indirects, sims, seed) {
  ssr_obs <- ssr(y_obs, cbind(1, z_obs, exposure_obs))
  pmat <- matrix(NA_real_, length(directs), length(indirects))
  set.seed(seed)
  for (j in seq_along(directs)) {
    for (k in seq_along(indirects)) {
      direct_sim <- directs[j]
      indirect_sim <- indirects[k]
      ssr_sims <- numeric(sims)
      for (i in seq_len(sims)) {
        z_sim <- z_block[, sample(ncol(z_block), 1)]
        exposure_sim <- net_exposure(similarity, z_sim, expected_1, expected_0)
        pure_y0 <- y_obs - exposure_obs * indirect_sim
        pure_y0[z_obs == 1] <- pure_y0[z_obs == 1] - direct_sim
        y_sim <- pure_y0 + direct_sim * z_sim + indirect_sim * exposure_sim
        ssr_sims[i] <- ssr(y_sim, cbind(1, z_sim, exposure_sim))
      }
      pmat[j, k] <- mean(ssr_obs > ssr_sims)
    }
  }
  summarize_pvalue_grid(pmat, directs, indirects)
}

# tile_grid ----
# Long form of a p-value matrix, for geom_tile.
tile_grid <- function(fit) {
  expand_grid(x = fit$directs, y = fit$indirects) |>
    mutate(z = as.vector(fit$pmat))
}

# make_pvalue_tile ----
# The lattice::levelplot p-value maps of the original, redrawn in ggplot2. `grid` has
# columns x, y and z, where z is the p-value.
make_pvalue_tile <- function(grid,
                             xlab = "Hypothesized direct effect",
                             ylab = "Hypothesized indirect effect") {
  ggplot(grid, aes(x = x, y = y, fill = z)) +
    geom_tile() +
    scale_fill_gradient(low = "white", high = "black", limits = c(0, 1),
                        name = "p-value") +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_vline(xintercept = 0, linetype = "dashed") +
    labs(x = xlab, y = ylab) +
    theme_bw()
}

# ci_arrow ----
# The double-headed 95% confidence region bars the original drew with lattice::larrows.
ci_arrow <- function(x, xend, y, yend) {
  annotate("segment", x = x, xend = xend, y = y, yend = yend,
           arrow = arrow(ends = "both", angle = 90, length = unit(0.05, "inches")))
}

# save_figure ----
# PDF for the report, PNG for the web, same plot and same dimensions.
save_figure <- function(plot, name, width = 7, height = 7) {
  ggsave(here::here("maintained", "output", str_glue("{name}.pdf")),
         plot = plot, width = width, height = height)
  ggsave(here::here("maintained", "output", str_glue("{name}.png")),
         plot = plot, width = width, height = height, dpi = 300)
}
