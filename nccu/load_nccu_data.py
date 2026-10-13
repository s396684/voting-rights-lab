import requests
import pandas as pd
import geopandas as gpd

gen_prov_24_link = (
    "https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/2024_11_05/provisional_20241105.txt"
)

snapshot_24_link = (
    "https://s3.amazonaws.com/dl.ncsbe.gov/data/Snapshots/VR_Snapshot_20241105.zip"
)

reg_26_link = ()

gen_prov_24 = pd.read_csv(
    gen_prov_24_link,
    sep="\t",
    dtype=str,
    encoding="utf-16",
)

chunks = pd.read_csv(
    snapshot_24_link,
    sep="\t",
    dtype=str,
    encoding="utf-16",
    on_bad_lines="skip",
    chunksize=500_000,
)
snapshot_24 = pd.concat(chunks, ignore_index=True)

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

print(gen_prov_24.columns)
print(gen_prov_24.head())

nccu_prov_24 = gen_prov_24.loc[gen_prov_24["reg_pct_lbl"] == "55-49"]
import requests
import pandas as pd
import geopandas as gpd

gen_prov_24_link = (
    "https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/2024_11_05/provisional_20241105.txt"
)

snapshot_24_link = (
    "https://s3.amazonaws.com/dl.ncsbe.gov/data/Snapshots/VR_Snapshot_20241105.zip"
)

reg_26_link = ()

gen_prov_24 = pd.read_csv(
    gen_prov_24_link,
    sep="\t",
    dtype=str,
    encoding="utf-16",
)

chunks = pd.read_csv(
    snapshot_24_link,
    sep="\t",
    dtype=str,
    encoding="utf-16",
    on_bad_lines="skip",
    chunksize=500_000,
)
snapshot_24 = pd.concat(chunks, ignore_index=True)

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

print(gen_prov_24.columns)
print(gen_prov_24.head())

nccu_prov_24 = gen_prov_24.loc[
    gen_prov_24["voted_pct_lbl"].str.strip().isin(["55-49", "55-11"])
]

snapshot_24_nccu = snapshot_24.loc[
    snapshot_24["precinct_abbrv"].str.strip().isin(["55-49", "55-11"])
][snapshot_cols_of_interest].copy()

nccu_prov_24.to_csv("data/processed/nccu_prov_24.csv", index=False)
snapshot_24_nccu.to_csv("data/processed/snapshot_24_nccu.csv", index=False)
print("Provisionals:", len(nccu_prov_24))
