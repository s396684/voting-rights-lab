import pandas as pd

provisionals_nccu_24 = pd.read_csv("data/processed/nccu_prov_2024.csv")
undeliverables = pd.read_csv("data/processed/2026_undeliverables_nccu.csv")

prov = provisionals_nccu_24.copy()
und = undeliverables.copy()

# matching names to voter reg file
cols = [
    "county_desc",
    "voter_reg_num",
    "ncid",
    "last_name",
    "first_name",
    "middle_name",
    "name_suffix_lbl",
    "voter_status_desc",
    "voter_status_reason_desc",
    "res_street_address",
    "res_city_desc",
    "state_cd",
    "full_phone_number",
    "birth_year",
    "age_at_year_end",
    "hava_id_req",
    "precinct_abbrv",
    "precinct_desc",
]
reg = pd.read_csv(
    "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvoter_Statewide.zip",
    sep="\t",
    dtype=str,
    encoding="latin-1",
    usecols=cols,
)

prov["prov_row"] = range(len(prov))


def id_key(s):
    return pd.to_numeric(s, errors="coerce").astype("Int64")


def squash(s):
    return s.astype("string").str.upper().str.replace(r"[^A-Z]", "", regex=True)


# --- prov keys ---
prov["county_key"] = id_key(prov["county_id"])
prov["voter_reg_num_key"] = id_key(prov["voter_reg_num"])
parts = prov["full_name"].str.split(",", n=1, expand=True)  # "LAST, FIRST MIDDLE"
prov["last_key"] = squash(parts[0])
prov["first_key"] = squash(parts[1].str.strip().str.split().str[0])

# --- read snapshot_26 in chunks, keep Durham + any row sharing a last name with a provisional ---
prov_last = set(prov["last_key"].dropna())
kept = []
for ch in pd.read_csv("data/processed/snapshot_26.csv", dtype=str, chunksize=500_000):
    ch["last_key"] = squash(ch["last_name"])
    keep = (id_key(ch["county_id"]) == 32) | ch["last_key"].isin(prov_last)
    kept.append(ch[keep])
snap = pd.concat(kept, ignore_index=True)

snap["county_key"] = id_key(snap["county_id"])
snap["voter_reg_num_key"] = id_key(snap["voter_reg_num"])
snap["first_key"] = squash(snap["first_name"].str.strip().str.split().str[0])

# prefix every snapshot column except the join keys
key_cols = ["county_key", "voter_reg_num_key", "last_key", "first_key"]
snap = snap.rename(columns={c: f"snap_{c}" for c in snap.columns if c not in key_cols})

helper_cols = ["prov_row", "county_key", "voter_reg_num_key", "last_key", "first_key"]

# --- pass 1: Durham + voter_reg_num ---
id_keys = ["county_key", "voter_reg_num_key"]
s_id = (
    snap[snap["county_key"] == 32]
    .dropna(subset=["voter_reg_num_key"])
    .drop_duplicates(id_keys)
    .drop(columns=["last_key", "first_key"])
)
m1 = (
    prov.dropna(subset=["voter_reg_num_key"])
    .merge(s_id, on=id_keys, how="inner")
    .assign(match_type="voter_reg_num")
)

# --- pass 2: first + last name within Durham ---
rest = prov[~prov["prov_row"].isin(m1["prov_row"])]
name_keys = ["county_key", "last_key", "first_key"]
s_dur = (
    snap[snap["county_key"] == 32]
    .drop_duplicates(name_keys, keep=False)  # drop ambiguous names
    .drop(columns=["voter_reg_num_key"])
)
m2 = rest.merge(s_dur, on=name_keys, how="inner").assign(match_type="name_durham")

# --- pass 3: first + last name statewide (people who moved counties) ---
rest = rest[~rest["prov_row"].isin(m2["prov_row"])]
k3 = ["last_key", "first_key"]
s_state = snap.drop_duplicates(k3, keep=False).drop(
    columns=["county_key", "voter_reg_num_key"]
)
m3 = rest.merge(s_state, on=k3, how="inner").assign(match_type="name_statewide")

unmatched = rest[~rest["prov_row"].isin(m3["prov_row"])].assign(match_type="unmatched")

merged = (
    pd.concat([m1, m2, m3, unmatched], ignore_index=True)
    .sort_values("prov_row")
    .reset_index(drop=True)
)

# --- flags ---
merged["snap_registered"] = merged["snap_voter_status_desc"].isin(
    ["ACTIVE", "INACTIVE"]
)
merged["snap_undeliverable"] = merged["snap_voter_status_reason_desc"].str.contains(
    "UNDELIVERABLE", case=False, na=False
)
reg_dt = pd.to_datetime(merged["snap_registr_dt"], format="%m/%d/%Y", errors="coerce")
merged["snap_registered_by_election"] = reg_dt <= pd.Timestamp("2024-11-05")

# drop only my helper columns, then put the key columns first
merged = merged.drop(columns=[c for c in helper_cols if c in merged.columns])

front = [
    "full_name",
    "pv_status",
    "not_counted_reason",
    "match_type",
    "snap_voter_status_desc",
    "snap_voter_status_reason_desc",
    "snap_registered",
    "snap_undeliverable",
    "snap_registr_dt",
    "snap_registered_by_election",
]
merged = merged[front + [c for c in merged.columns if c not in front]]

# --- diagnostics ---
print(merged["match_type"].value_counts())
print("total matched:", (merged["match_type"] != "unmatched").sum())
print(merged["snap_voter_status_desc"].value_counts(dropna=False))
print("registered (active or inactive):", merged["snap_registered"].sum())
print("undeliverable:", merged["snap_undeliverable"].sum())

merged.to_csv("data/processed/nccu_prov_2024_snapshot_26.csv", index=False)
