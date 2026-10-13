"""Download 2024 NCSBE files and keep NCCU's two precincts (55-49 and 55-11).

Provisional ballots are kept by WHERE THE BALLOT WAS CAST (voted_pct_lbl).
Run from the repo root:  python nccu/load_nccu_data.py
"""
import pandas as pd

NCCU_PRECINCTS = ["55-49", "55-11"]

prov_24_link = "https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/2024_11_05/provisional_20241105.txt"
snapshot_24_link = "https://s3.amazonaws.com/dl.ncsbe.gov/data/Snapshots/VR_Snapshot_20241105.zip"

# ---- 1. Provisional ballots cast in the NCCU precincts ------------------------
prov_24 = pd.read_csv(prov_24_link, sep="\t", dtype=str, encoding="utf-16")
prov_24.columns = prov_24.columns.str.strip()

nccu_prov_24 = prov_24.loc[
    prov_24["voted_pct_lbl"].str.strip().isin(NCCU_PRECINCTS)
    & (prov_24["county_name"].str.strip() == "DURHAM")
].copy()
nccu_prov_24.to_csv("data/processed/nccu_prov_24.csv", index=False)
print("Provisional ballots cast in 55-49 + 55-11:", len(nccu_prov_24))
print(nccu_prov_24["voted_pct_lbl"].value_counts())

# ---- 2. Election-day 2024 snapshot (big: read in chunks, keep Durham only) --
snapshot_cols = [
    "snapshot_dt", "county_id", "county_desc", "voter_reg_num", "ncid",
    "status_cd", "voter_status_desc", "reason_cd", "voter_status_reason_desc",
    "absent_ind", "name_prefx_cd", "last_name", "first_name", "midl_name",
    "name_sufx_cd", "house_num", "half_code", "street_dir", "street_name",
    "street_type_cd", "street_sufx_cd", "unit_designator", "unit_num",
    "res_city_desc", "state_cd", "zip_code", "mail_addr1", "mail_addr2",
    "mail_addr3", "mail_addr4", "mail_city", "mail_state", "mail_zipcode",
    "area_cd", "phone_num", "race_code", "race_desc", "ethnic_code",
    "ethnic_desc", "party_cd", "party_desc", "sex_code", "sex", "age",
    "birth_place", "registr_dt", "precinct_abbrv", "precinct_desc",
]

durham_chunks = []
for chunk in pd.read_csv(snapshot_24_link, sep="\t", dtype=str, encoding="utf-16",
                         on_bad_lines="skip", chunksize=500_000):
    chunk.columns = chunk.columns.str.strip()
    durham_chunks.append(chunk.loc[chunk["county_desc"].str.strip() == "DURHAM", snapshot_cols])
snapshot_24_durham = pd.concat(durham_chunks, ignore_index=True)

# NCCU precincts only (this file goes on GitHub)
snapshot_24_nccu = snapshot_24_durham.loc[
    snapshot_24_durham["precinct_abbrv"].str.strip().isin(NCCU_PRECINCTS)
]
snapshot_24_nccu.to_csv("data/processed/snapshot_24_nccu.csv", index=False)
print("Snapshot rows in 55-49 + 55-11:", len(snapshot_24_nccu))

# Provisional voters registered ELSEWHERE in Durham still need their status, so
# also save just those people's snapshot rows.
prov_reg_nums = set(nccu_prov_24["voter_reg_num"].str.strip())
snapshot_24_prov = snapshot_24_durham.loc[
    snapshot_24_durham["voter_reg_num"].str.strip().isin(prov_reg_nums)
]
snapshot_24_prov.to_csv("data/processed/snapshot_24_prov_voters.csv", index=False)
print("Provisional voters found in the Durham snapshot:", len(snapshot_24_prov))
