# coppock_2014/maintained/text_total_causal_effect.R
# Output: maintained/output/text_total_causal_effect.csv
# Depends on: maintained/data/spillovers.rds, figure_1a.rds, figure_2.rds, helpers.R
# Description: The in-text quantities on page 167: the difference-in-means implied
#   change in votes, and the total causal effect the spillover model implies, which is
#   the number of legislators who would have voted yea in the uniformity trial against
#   the number who actually did.
#
#   Reported under the corrected and the uncorrected ideological similarity matrix,
#   since the uniformity trial is evaluated at Figure 2's point estimates.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))
figure_1a <- read_rds(here::here("maintained", "data", "figure_1a.rds"))
figure_2 <- read_rds(here::here("maintained", "data", "figure_2.rds"))

dat <- spillovers$data
z_obs <- dat$treatment
y_obs <- dat$sb24

uniformity_yeas <- function(fit, exposure_obs) {
  pure_y0 <- y_obs - exposure_obs * fit$indirect_point
  pure_y0[z_obs == 1] <- pure_y0[z_obs == 1] - fit$direct_point
  sum(pure_y0, na.rm = TRUE)
}

yeas_corrected <- uniformity_yeas(figure_2$corrected, spillovers$exposure_dw$observed)
yeas_uncorrected <- uniformity_yeas(figure_2$uncorrected,
                                    spillovers$exposure_dw_deposited$observed)
yeas_observed <- sum(y_obs, na.rm = TRUE)

text_quantities <- tibble(
  claim = c("Legislators treated",
            "Difference-in-means estimate (Figure 1a)",
            "Implied change in votes under the difference in means",
            "Legislators voting yea",
            "Yea votes in the uniformity trial, uncorrected",
            "Total causal effect in votes, uncorrected",
            "Yea votes in the uniformity trial, corrected",
            "Total causal effect in votes, corrected"),
  value = c(sum(z_obs),
            figure_1a$ate_point,
            sum(z_obs) * figure_1a$ate_point,
            yeas_observed,
            yeas_uncorrected,
            yeas_uncorrected - yeas_observed,
            yeas_corrected,
            yeas_corrected - yeas_observed)
)

write_csv(text_quantities,
          here::here("maintained", "output", "text_total_causal_effect.csv"))
print(text_quantities)
