# coppock_2014/maintained/clean_data.R
# Output: maintained/data/spillovers.rds
# Depends on: original/CoppockJEPS.RData, original/hd_court_ordered.shp,
#   original_corrigendum/CoppockJEPS.rdata, helpers.R
# Description: Builds every object the figure scripts need: the analysis frame, the
#   10,000 admissible randomizations, the four similarity matrices, and the expected
#   and observed net exposures that go with each.
#
#   The deposited CoppockJEPS.RData carries a similarity.matrix.dw that is 1 off the
#   diagonal and 0 on it, which says every pair of legislators is maximally and equally
#   close in ideological space. That is the coding error the corrigendum reports
#   (Coppock 2016, JEPS 3(2): 206-208). The matrix is rebuilt here using Equation (1)
#   from the W-NOMINATE scores in the corrigendum's own deposit. The rank, squared-distance and geographic
#   matrices in the deposit are correct and are rebuilt and checked against it.
#
#   The deposited all-ones matrix is kept under similarity_dw_deposited so the figure
#   scripts can reproduce the published, uncorrected maps alongside the corrected ones.

source(here::here("maintained", "helpers.R"))

# Deposited objects ----
load(here::here("original", "CoppockJEPS.RData"))
dat <- as_tibble(CoppockJEPS)

# Similarity matrices ----
# The three appendix parameterizations are rebuilt from the same deposited ideal points
# and agree with the deposit exactly, which is what isolates the defect to the main
# ideological similarity matrix.
# The corrected analysis uses the ideal points from the corrigendum's deposit
# (doi:10.7910/DVN/H47CC6), not the 2014 ones. 68 of the 70 differ, by up to 0.533. The
# transform is the same in both archives, so the matrices differ only because their
# inputs do, and that difference is the whole reason the corrigendum's numbers cannot
# be recovered from the 2014 deposit. Every other column of the two data frames agrees,
# so the rows align.
corrigendum <- new.env()
load(here::here("original_corrigendum", "CoppockJEPS.rdata"), envir = corrigendum)
dwnom_corrigendum <- corrigendum$CoppockJEPS$dwnom_scores
similarity_dw <- similarity_from_scores(dwnom_corrigendum)

# The three appendix parameterizations stay on the deposited scores, which is what
# reproduces the appendix as published. The corrigendum does not touch them.
similarity_rank <- similarity_from_scores(
  rank(dat$dwnom_scores, na.last = "keep"),
  transform = function(x, y) (67 - abs(x - y)) / 67
)
similarity_sq <- similarity_from_scores(
  dat$dwnom_scores,
  transform = function(x, y) (4 - (x - y)^2) / 4
)

# The geographic contiguity matrix came from maptools::readShapeSpatial, which left CRAN
# in 2023. sf::st_read reads the same deposited shapefile and spdep builds the same
# adjacency matrix from it, to the byte.
districts <- st_read(here::here("original", "hd_court_ordered.shp"), quiet = TRUE)
similarity_geo <- nb2mat(poly2nb(districts), style = "B")
rownames(similarity_geo) <- NULL

rebuild_check <- tibble(
  matrix = c("rank", "squared", "geographic", "ideological"),
  max_abs_deviation_from_deposit = c(
    max(abs(similarity_rank - similarity.matrix.rank)),
    max(abs(similarity_sq - similarity.matrix.sq)),
    max(abs(similarity_geo - similarity.matrix.geo)),
    max(abs(similarity_dw - similarity.matrix.dw))
  )
)
print(rebuild_check)

# Exposures ----
# One set of expected and observed net exposures per similarity matrix, plus a set built
# from the deposited all-ones matrix for the uncorrected comparison figures.
z_obs <- dat$treatment

exposures <- function(similarity) {
  expected <- expected_exposure(similarity, Z_block)
  list(
    expected_1 = expected$expected_1,
    expected_0 = expected$expected_0,
    observed = net_exposure(similarity, z_obs, expected$expected_1, expected$expected_0)
  )
}

exposure_dw <- exposures(similarity_dw)
exposure_rank <- exposures(similarity_rank)
exposure_sq <- exposures(similarity_sq)
exposure_geo <- exposures(similarity_geo)

# The deposited all-ones matrix gives every unit the same raw exposure, so its own net
# exposure has zero variance and cannot be standardized. The published analysis
# regressed on the correct net exposure and simulated with the all-ones matrix; that
# mixture is what the uncorrected figures reproduce.
exposure_dw_deposited <- list(
  expected_1 = dat$exposure.expected.1.dw,
  expected_0 = dat$exposure.expected.0.dw,
  observed = as.vector(dat$s.difs.dw)
)

deposited_check <- tibble(
  quantity = c("net exposure", "expected exposure under treatment",
               "expected exposure under control"),
  max_abs_deviation_from_deposit = c(
    max(abs(exposure_dw$observed - as.vector(dat$s.difs.dw))),
    max(abs(exposure_dw$expected_1 - dat$exposure.expected.1.dw)),
    max(abs(exposure_dw$expected_0 - dat$exposure.expected.0.dw))
  )
)
print(deposited_check)

# Assemble ----
spillovers <- list(
  data = dat |> select(id, treatment, sb24, lowsupport, dwnom_scores, match_category),
  z_block = Z_block,
  similarity_dw = similarity_dw,
  similarity_dw_deposited = similarity.matrix.dw,
  similarity_rank = similarity_rank,
  similarity_sq = similarity_sq,
  similarity_geo = similarity_geo,
  exposure_dw = exposure_dw,
  exposure_dw_deposited = exposure_dw_deposited,
  exposure_rank = exposure_rank,
  exposure_sq = exposure_sq,
  exposure_geo = exposure_geo
)

write_rds(spillovers, here::here("maintained", "data", "spillovers.rds"))
