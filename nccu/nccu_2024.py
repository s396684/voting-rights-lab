import re
import pandas as pd
import geopandas as gpd

snapshot_24_link = "data/processed/snapshot_25_nccu.csv"
snap = pd.read_csv(snapshot_24_link)

nccu_prov_2024_link = "data/processed/nccu_prov_2024.csv"
prov = pd.read_csv(nccu_prov_2024_link)

for df in (snap, prov):
    df.columns = df.columns.str.strip()
    df["county_id"] = pd.to_numeric(df["county_id"], errors="coerce")


def last(s):
    return re.sub(r"[^A-Z]", "", str(s).split(",")[0].upper())


def names(s):
    return (
        set()
        if pd.isna(s)
        else set(re.sub(r"[^A-Z ]", " ", str(s).upper().replace("'", "")).split())
    )


prov["id"] = prov.index
prov["last_sq"] = prov["full_name"].map(last)
prov["given"] = prov["full_name"].str.split(",", n=1).str[1].map(names)
snap["last_sq"] = snap["last_name"].map(last)
snap["given_snap"] = [
    names(f) | names(m) for f, m in zip(snap["first_name"], snap["midl_name"])
]

m = prov.merge(snap, on=["county_id", "last_sq"], how="left", suffixes=("", "_snap"))
m["reg_hit"] = m["voter_reg_num"] == m["voter_reg_num_snap"]
m["overlap"] = [
    len(a & b) if isinstance(b, set) else 0 for a, b in zip(m["given"], m["given_snap"])
]

best = (
    m[m["reg_hit"] | (m["overlap"] > 0)]
    .sort_values(["reg_hit", "overlap"], ascending=False)
    .drop_duplicates("id")
)

result = prov.merge(
    best[
        [
            "id",
            "ncid",
            "voter_status_desc",
            "registr_dt",
            "first_name",
            "midl_name",
            "last_name",
        ]
    ],
    on="id",
    how="left",
)
result["matched"] = result["ncid"].notna()

print(len(prov), len(result))
print(result["matched"].value_counts())
