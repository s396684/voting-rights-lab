import pandas as pd

pcts = ["55-49", "55-11"]

snapshot_26_link = (
    "https://s3.amazonaws.com/dl.ncsbe.gov/data/Snapshots/VR_Snapshot_20260303.zip"
)
chunks = pd.read_csv(
    snapshot_26_link,
    sep="\t",
    dtype=str,
    encoding="utf-16",
    on_bad_lines="skip",  # double check; may create problems later
    chunksize=500_000,
)
snapshot_26 = pd.concat(chunks, ignore_index=True)
snapshot_26.to_csv("data/processed/snapshot_26.csv", index=False)

snapshot_cols_of_interest = [
    "snapshot_dt",
    "county_id",
    "county_desc",
    "voter_reg_num",
    "ncid",
    "status_cd",
    "voter_status_desc",
    "reason_cd",
    "voter_status_reason_desc",
    "absent_ind",
    "name_prefx_cd",
    "last_name",
    "first_name",
    "midl_name",
    "name_sufx_cd",
    "house_num",
    "half_code",
    "street_dir",
    "street_name",
    "street_type_cd",
    "street_sufx_cd",
    "unit_designator",
    "unit_num",
    "res_city_desc",
    "state_cd",
    "zip_code",
    "mail_addr1",
    "mail_addr2",
    "mail_addr3",
    "mail_addr4",
    "mail_city",
    "mail_state",
    "mail_zipcode",
    "area_cd",
    "phone_num",
    "race_code",
    "race_desc",
    "ethnic_code",
    "ethnic_desc",
    "party_cd",
    "party_desc",
    "sex_code",
    "sex",
    "age",
    "birth_place",
    "registr_dt",
    "precinct_abbrv",
    "precinct_desc",
]

snapshot_26_nccu = snapshot_26.loc[
    snapshot_26["precinct_abbrv"].str.strip().isin(pcts)
][snapshot_cols_of_interest].copy()
snapshot_26_nccu["year"] = "2026"

snapshot_26_nccu["age"] = pd.to_numeric(snapshot_26_nccu["age"], errors="coerce")

snapshot_26_nccu_u30 = snapshot_26_nccu.loc[snapshot_26_nccu["age"] < 30].copy()

snapshot_26_nccu_u30.to_csv("data/processed/snapshot_26_nccu_u30.csv", index=False)

snapshot_26_undeliv = snapshot_26_nccu.loc[
    snapshot_26_nccu["voter_status_reason_desc"].str.contains(
        "UNDELIVERABLE", case=False, na=False
    )
].copy()

snapshot_26_undeliv.to_csv("data/processed/2026_undeliverables_nccu.csv", index=False)
snapshot_26_nccu.to_csv("data/processed/undeliverables_2026_nccu.csv", index=False)
