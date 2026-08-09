# coppock_2014/run_all.R
# Runs the whole reproduction in order: fetch and verify the deposited archive, rebuild
# the similarity matrices and exposures, then every published figure, then the appendix
# tables and the in-text quantities.
# Every script is self-contained and can also be run on its own.

library(here)
here::i_am("run_all.R")

# Deposited archive ----
# Downloads from Dataverse on a fresh clone; verifies checksums either way.
source(here::here("download_original.R"))

# Cleaning ----
source(here::here("maintained", "clean_data.R"))

# Figures ----
source(here::here("maintained", "figure_1a_no_spillover.R"))
source(here::here("maintained", "figure_1b_no_spillover_hetero.R"))
source(here::here("maintained", "figure_2_ideo_spillover.R"))
source(here::here("maintained", "text_sampler_reproducibility.R"))
source(here::here("maintained", "figure_3_hetero_spillover.R"))
source(here::here("maintained", "figure_a1_ideal_points.R"))
source(here::here("maintained", "figure_a2_rank_spillover.R"))
source(here::here("maintained", "figure_a3_squared_spillover.R"))
source(here::here("maintained", "figure_a4_geo_spillover.R"))
# The four-parameter model is the slow step: a 13^4 grid at 50 simulations a cell,
# computed twice.
source(here::here("maintained", "figure_a5_four_parameter.R"))

# Tables ----
# These read the figure scripts' saved fits, so they run after them.
source(here::here("maintained", "table_1_constant_effects.R"))
source(here::here("maintained", "table_2_hetero_effects.R"))

# In-text quantities ----
source(here::here("maintained", "text_total_causal_effect.R"))
source(here::here("maintained", "text_design_parameters.R"))

# Figure timestamps ----
# R's pdf() device stamps a wall-clock /CreationDate and /ModDate into every figure it
# writes, and those two fields are the only reason two runs of this pipeline produce
# differing files. Blanking them lets the determinism check cover every file the
# pipeline writes rather than all but the figures.
source(here::here("maintained", "helpers.R"))
walk(
  list.files(here::here("maintained", "output"), pattern = "\\.pdf$", full.names = TRUE),
  blank_pdf_timestamps
)

# Ground truth and the coverage gate ----
# build_ground_truth.R assembles the comparison table and then runs in_text_claims.R
# under capture.output, so a claim block that errors or prints nothing stops the build.
# in_text_claims.R is run again here for the human-readable log. Both are sourced into
# their own environments: they read the same outputs and name objects for what those
# hold, so a bare source() would leave one file's accessors in place of the other's.
source(here::here("ground_truth", "build_ground_truth.R"), local = new.env())
source(here::here("maintained", "in_text_claims.R"), local = new.env())

# Deposited archive, again ----
# The check at the top of this file is a precondition: it says original/ was intact
# before anything ran. Nothing above writes to original/, and this second pass is what
# demonstrates it rather than assuming it. Nothing is downloaded; the files are already
# present and are re-checked against the manifest on checksum, byte size and membership.
source(here::here("download_original.R"))
