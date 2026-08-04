# Recovered materials

Files the author supplied that the Dataverse deposit does not contain. They are
committed because they exist nowhere public, which is the opposite of the rule
for `original/`.

## `dwnom_scores_version_3.csv`

The 70 W-NOMINATE ideal points from "Coppock JEPS Replication Archive Version 3",
the working archive behind the 2016 corrigendum. They are not the scores in the
deposit: 68 of the 70 differ, by up to 0.533, correlation 0.978.

That difference is why the corrigendum's numbers cannot be recovered from the
deposit. The similarity transform is identical in both archives, `(2 - |x - y|)/2`
with a zeroed diagonal, so the matrices differ only because their inputs do. These
scores regenerate the Version 3 similarity matrix exactly and its expected
exposures to 3.6e-15, so they are the whole of what needs carrying across.

The corrected analysis uses these. The as-published 2014 figures continue to use
the deposit, because that is what reproduces what was printed.

So does the corrigendum's own original panel, which is the published uncorrected
analysis rerun in the Version 3 archive. That is easy to miss: under the all-ones
matrix every unit's raw exposure is identical, so the simulated exposure varies only
through the expected-exposure term, which these scores build. The uncorrected model
therefore moves with the ideal points too, and on these scores it returns the
confidence intervals the corrigendum restates rather than the ones appendix Table 1
prints.
