# voting-rights-lab

Student Voting Rights Lab (Duke) — analysis of NC State Board of Elections data on
student voting, provisional ballots, and unverifiable registrations.

**Start here: [WORKPLAN.md](WORKPLAN.md)** — the NCCU campus portrait tasks, run order,
preliminary findings, and caveats.

## Layout
```
data/raw/            big downloads + unverifiable-address files (git-ignored)
data/processed/      NCCU-precinct extracts
data/derived/        person-level analysis files (git-ignored)
output/tables/       aggregate CSVs (safe to share)
output/figures/      PNG figures
*.py                 earlier Python loaders (pandas)
```

## Run
From the repo root in R/RStudio:
```r
source("R/01_get_ncsbe_data.R")   # once; slow (multi-GB snapshots)
source("R/run_all.R")
```
