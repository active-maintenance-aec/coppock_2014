# coppock_2014/maintained/figure_a1_ideal_points.R
# Output: maintained/output/figure_a1_ideal_points.csv
#         maintained/output/figure_a1_ideal_points.pdf
#         maintained/output/figure_a1_ideal_points.png
# Depends on: maintained/data/spillovers.rds, helpers.R
# Description: Appendix Figure 1. Distribution of the estimated W-NOMINATE ideal points
#   that Equation (1) turns into the ideological similarity matrix. The original drew
#   this inside CoppockJEPS_datapreparation.R, the one archive script that does not run
#   today; it is a figure of its own here.

source(here::here("maintained", "helpers.R"))

spillovers <- read_rds(here::here("maintained", "data", "spillovers.rds"))

gg_df <- spillovers$data |>
  select(dwnom_scores) |>
  drop_na()

g <- ggplot(gg_df, aes(x = dwnom_scores)) +
  geom_histogram(bins = 50, fill = "grey80", colour = "black", linewidth = 0.2) +
  labs(x = "W-NOMINATE score", y = "Frequency") +
  theme_bw()

save_figure(g, "figure_a1_ideal_points", width = 6, height = 5)

estimates <- tibble(
  claim = c("Appendix Figure A1: legislators with an ideal point",
            "Appendix Figure A1: minimum score",
            "Appendix Figure A1: maximum score"),
  value = round(c(nrow(gg_df), min(gg_df$dwnom_scores), max(gg_df$dwnom_scores)), 6)
)

write_csv(estimates, here::here("maintained", "output", "figure_a1_ideal_points.csv"))
print(estimates)
