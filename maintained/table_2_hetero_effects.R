# coppock_2014/maintained/table_2_hetero_effects.R
# Output: maintained/output/table_2_hetero_effects.csv
# Depends on: maintained/data/figure_1b.rds, figure_3.rds, helpers.R
# Description: Appendix Table 2, the summary of the heterogeneous effects models, with
#   the absolute distance column in both its corrected and its published form.

source(here::here("maintained", "helpers.R"))

figure_1b <- read_rds(here::here("maintained", "data", "figure_1b.rds"))
figure_3 <- read_rds(here::here("maintained", "data", "figure_3.rds"))

# Bounds land on grid points such as -0.075, which floating point stores as
# -0.0750000000000001; rounding at the display step keeps that out of the CSV.
format_ci <- function(bounds) {
  bounds <- round(bounds, 6)
  str_glue("[{bounds[1]},{bounds[2]}]")
}

spillover_column <- function(fit) {
  c(as.character(round(fit$high$direct_point, 6)), format_ci(fit$high$direct_ci),
    as.character(round(fit$high$indirect_point, 6)), format_ci(fit$high$indirect_ci),
    as.character(round(fit$low$direct_point, 6)), format_ci(fit$low$direct_ci),
    as.character(round(fit$low$indirect_point, 6)), format_ci(fit$low$indirect_ci),
    "3")
}

table_2 <- tibble(
  quantity = c("Direct Effect, High Support", "Direct 95% CI, High Support",
               "Indirect Effect, High Support", "Indirect 95% CI, High Support",
               "Direct Effect, Low Support", "Direct 95% CI, Low Support",
               "Indirect Effect, Low Support", "Indirect 95% CI, Low Support",
               "Corresponding Figure"),
  no_spillover = c(as.character(round(figure_1b$high_point, 6)), format_ci(figure_1b$high_ci),
                   NA, NA,
                   as.character(round(figure_1b$low_point, 6)), format_ci(figure_1b$low_ci),
                   NA, NA, "1b"),
  absolute_distance = spillover_column(figure_3$corrected),
  absolute_distance_uncorrected = spillover_column(figure_3$uncorrected)
)

write_csv(table_2, here::here("maintained", "output", "table_2_hetero_effects.csv"))
print(table_2)
