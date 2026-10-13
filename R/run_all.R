# Run the whole NCCU pipeline from the repo root:  source("R/run_all.R")
# Step 1 (downloads, slow) — comment out once data/processed/ is filled in.
# source("R/01_get_ncsbe_data.R")
source("R/10_q1_provisional_followup.R")
source("R/11_q2_address_1801.R")
source("R/12_q3_unverified_provisional_link.R")
message("Tables: output/tables/   Figures: output/figures/")
