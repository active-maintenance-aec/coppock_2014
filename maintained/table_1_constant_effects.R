# coppock_2014/maintained/table_1_constant_effects.R
# Output: maintained/output/table_1_constant_effects.csv
# Depends on: maintained/data/figure_1a.rds, figure_2.rds, figure_a2.rds,
#             figure_a3.rds, figure_a4.rds, helpers.R
# Description: Appendix Table 1, the summary of the constant effects models. The
#   absolute distance column appears twice: once from the corrected ideological
#   similarity matrix, and once from the all-ones matrix the deposit stores, which is
#   the column the appendix prints. Every cell is read from a figure script's saved
#   fit; none is transcribed from the article.

source(here::here("maintained", "helpers.R"))

figure_1a <- read_rds(here::here("maintained", "data", "figure_1a.rds"))
figure_2 <- read_rds(here::here("maintained", "data", "figure_2.rds"))
figure_a2 <- read_rds(here::here("maintained", "data", "figure_a2.rds"))
figure_a3 <- read_rds(here::here("maintained", "data", "figure_a3.rds"))
figure_a4 <- read_rds(here::here("maintained", "data", "figure_a4.rds"))

# Bounds land on grid points such as -0.075, which floating point stores as
# -0.0750000000000001; rounding at the display step keeps that out of the CSV.
format_ci <- function(bounds) {
  bounds <- round(bounds, 6)
  str_glue("[{bounds[1]},{bounds[2]}]")
}

spillover_column <- function(fit, figure_label) {
  c(as.character(round(fit$direct_point, 6)), format_ci(fit$direct_ci),
    as.character(round(fit$indirect_point, 6)), format_ci(fit$indirect_ci), figure_label)
}

table_1 <- tibble(
  quantity = c("Direct Effect", "Direct 95% CI", "Indirect Effect",
               "Indirect 95% CI", "Corresponding Figure"),
  no_spillover = c(as.character(round(figure_1a$ate_point, 6)), format_ci(figure_1a$ate_ci),
                   NA, NA, "1a"),
  absolute_distance = spillover_column(figure_2$corrected, "2"),
  absolute_distance_uncorrected = spillover_column(figure_2$uncorrected, "2"),
  rank_distance = spillover_column(figure_a2, "A2"),
  squared_distance = spillover_column(figure_a3, "A3"),
  geographic_contiguity = spillover_column(figure_a4, "A4")
)

write_csv(table_1, here::here("maintained", "output", "table_1_constant_effects.csv"))
print(table_1)
