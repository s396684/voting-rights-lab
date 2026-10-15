import requests
import pandas as pd
import geopandas as gpd

# nccu provisional ballots '24

prov_links = {
    "2016": "https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/2016_11_08/provisional_20161108.txt",
    "2018": "https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/2018_11_06/provisional_20181106.txt",
    "2020": "https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/2020_11_03/provisional_20201103.txt",
    "2022": "https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/2022_11_08/provisional_20221108.txt",
    "2024": "https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/2024_11_05/provisional_20241105.txt",
}

pcts = ["55-49", "55-11"]

for year, gen_prov_link in prov_links.items():
    gen_prov = pd.read_csv(
        gen_prov_link,
        sep="\t",
        dtype=str,
        encoding="utf-16",
    )

    nccu_prov = gen_prov.loc[(gen_prov["voted_pct_lbl"].isin(pcts))]
    nccu_prov["year"] = year
    print(f"{year}: {len(nccu_prov)} provisional ballots")
    nccu_prov.to_csv(f"data/processed/nccu_prov_{year}.csv", index=False)

# nccu snapshot files '24
snapshot_24_link = (
    "https://s3.amazonaws.com/dl.ncsbe.gov/data/Snapshots/VR_Snapshot_20241105.zip"
)
chunks = pd.read_csv(
    snapshot_24_link,
    sep="\t",
    dtype=str,
    encoding="utf-16",
    on_bad_lines="skip",  # double check; may create problems later
    chunksize=500_000,
)
snapshot_24 = pd.concat(chunks, ignore_index=True)
snapshot_24.to_csv("data/processed/snapshot_24.csv", index=False)


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

snapshot_24_nccu = snapshot_24.loc[
    snapshot_24["precinct_abbrv"].str.strip().isin(pcts)
][snapshot_cols_of_interest].copy()
snapshot_24_nccu["year"] = "2024"

snapshot_24_nccu.to_csv("data/processed/snapshot_24_nccu.csv", index=False)

# current voter registration files
reg_26_link = "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvoter32.zip"

reg_26 = pd.read_csv(
    reg_26_link,
    sep="\t",
    dtype=str,
    encoding="latin-1",
)

reg_26_nccu = reg_26.loc[reg_26["precinct_abbrv"].str.strip().isin(pcts)]

reg_26_cols_of_interest = [
    "county_id",
    "county_desc",
    "voter_reg_num",
    "ncid",
    "last_name",
    "first_name",
    "middle_name",
    "name_suffix_lbl",
    "status_cd",
    "voter_status_desc",
    "reason_cd",
    "voter_status_reason_desc",
    "res_street_address",
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
    "full_phone_number",
    "confidential_ind",
    "registr_dt",
    "race_code",
    "ethnic_code",
    "party_cd",
    "gender_code",
    "birth_year",
    "age_at_year_end",
    "birth_state",
    "drivers_lic",
    "ssn",
    "no_dl_ssn_chkbx",
    "hava_id_req",
    "precinct_abbrv",
    "precinct_desc",
]
reg_26_nccu = reg_26_nccu[reg_26_cols_of_interest]

reg_26_nccu.to_csv("data/processed/reg_26_nccu.csv", index=False)

# loading voter history file to verify provisional counts
hist_link = "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvhis32.zip"

hist = pd.read_csv(
    hist_link,
    sep="\t",
    dtype=str,
    encoding="latin-1",
)

hist.to_csv("data/processed/hist_general.csv", index=False)

hist_nccu = hist.loc[hist["pct_label"].str.strip().isin(pcts)]

hist_nccu.to_csv("data/processed/hist_nccu.csv", index=False)
