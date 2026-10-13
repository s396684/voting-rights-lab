# voting-rights-lab

Student Voting Rights Lab (Duke) — analysis of NC State Board of Elections data on
student voting, provisional ballots, and unverifiable registrations.

**Start here: [WORKPLAN.md](WORKPLAN.md)** — the NCCU campus portrait tasks, run order,
preliminary findings, and caveats.

## Layout
```
R/00_setup.R                         packages, paths, precincts, NCSBE file URLs, plot theme
R/01_get_ncsbe_data.R                download NCSBE files, cut to Durham 55-11 + 55-49
R/02_functions.R                     loaders, status groups, mailing-address classifier
R/10_q1_provisional_followup.R       Q1: where are 2024 NCCU provisional voters now?
R/11_q2_address_1801.R               Q2: is "bare 1801 Fayetteville" the problem?
R/12_q3_unverified_provisional_link.R Q3: unverified <-> provisional link, by election
R/run_all.R                          runs Q1-Q3
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
