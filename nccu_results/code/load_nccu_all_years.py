"""Get every file the NCCU campus portrait needs, cut down to NCCU's precincts.

Run from the repo root:   python nccu/load_nccu_all_years.py
(about 10-20 minutes; the 2024 snapshot is made separately by load_nccu_data.py)

Makes (in data/processed/  -- these have names/addresses, do NOT push to GitHub):
  nccu_prov_2016.csv ... nccu_prov_2024.csv
        provisional ballots CAST in 55-49 / 55-11 (voted_pct_lbl), one per election
  vhis_nccu_generals.csv
        Durham voter history: everyone who voted in 55-49 / 55-11 in each
        general election 2016-2024 (how many people voted successfully)
  reg_current_nccu_related.csv
        today's Durham registration record (all statuses: active, inactive,
        removed, denied) for: everyone in 55-49 / 55-11 or at 1801 Fayetteville, every
        provisional voter above, and every voter in the history file above.
        Gives birth_year (ages), current status, addresses, NCID.
Re-running skips files already made; delete one to rebuild it.
"""
import io
import os
import zipfile
import urllib.request

import pandas as pd

NCCU_PRECINCTS = {"55-49", "55-11"}
NCCU_KEYS = {"5549", "5511"}          # same precincts with punctuation removed


def is_nccu(labels):
    """True for 55-49 / 55-11 however the label is written (55-49, 5549, 55 49)."""
    return labels.str.upper().str.replace(r"[^0-9A-Z]", "", regex=True).isin(NCCU_KEYS)
OUT = "data/processed"
RAW = "data/raw"

ELECTIONS = {2016: "20161108", 2018: "20181106", 2020: "20201103",
             2022: "20221108", 2024: "20241105"}
DURHAM_REG_URL = "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvoter32.zip"
DURHAM_HIST_URL = "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvhis32.zip"


def prov_url(date):
    return (f"https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/"
            f"{date[:4]}_{date[4:6]}_{date[6:]}/provisional_{date}.txt")


def fetch(url, cache=None):
    """Download once; keep a copy in data/raw/ so re-runs are fast."""
    if cache and os.path.exists(cache):
        with open(cache, "rb") as f:
            return f.read()
    print("  downloading", url)
    with urllib.request.urlopen(url) as r:
        raw = r.read()
    if cache:
        os.makedirs(RAW, exist_ok=True)
        with open(cache, "wb") as f:
            f.write(raw)
    return raw


def unzip_first(raw):
    z = zipfile.ZipFile(io.BytesIO(raw))
    return z.read(z.namelist()[0])


def _clean(d):
    d.columns = d.columns.str.strip().str.lower()
    return d.apply(lambda c: c.str.strip())


def read_tab(raw, keep=None):
    """NCSBE files are tab-separated; some are UTF-16, some Latin-1.
    Read in chunks so big county files don't run the laptop out of memory;
    `keep(chunk)` returns the rows to keep from each chunk."""
    enc = "utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "latin-1"
    parts = []
    for chunk in pd.read_csv(io.BytesIO(raw), sep="\t", dtype=str, encoding=enc,
                             keep_default_na=False, on_bad_lines="skip",
                             chunksize=200_000):
        chunk = _clean(chunk)
        parts.append(chunk[keep(chunk)] if keep else chunk)
    return pd.concat(parts, ignore_index=True)


def norm(x):
    return " ".join("".join(ch if ch.isalnum() else " " for ch in str(x).upper()).split())


def last_of(full_name):          # "SMITH, JANE ANN" -> "SMITH"
    return norm(str(full_name).split(",")[0])


def first_of(full_name):         # "SMITH, JANE ANN" -> "JANE"
    rest = str(full_name).split(",", 1)[1] if "," in str(full_name) else ""
    w = norm(rest).split()
    return w[0] if w else ""


def in_durham(d):
    if "county_id" in d:
        return d["county_id"] == "32"
    return d["county_name"].str.upper().eq("DURHAM")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)

    # ---- 1. provisional ballots cast in NCCU precincts, every general ------
    prov_ids = set()
    prov_names = set()          # (LAST, FIRST) pairs, to find people by name later
    for year, date in ELECTIONS.items():
        out = f"{OUT}/nccu_prov_{year}.csv"
        if not os.path.exists(out):
            try:
                allp = read_tab(fetch(prov_url(date)))
                durham = allp[in_durham(allp)]
                d = durham[is_nccu(durham["voted_pct_lbl"])].copy()
            except Exception as e:
                print(f"!! {year}: could not read the provisional file ({e}).")
                print("   Find it on https://dl.ncsbe.gov/?prefix=ENRS/ and fix prov_url().")
                continue
            if d.empty:
                print(f"!! {year}: 0 NCCU rows. Durham precinct labels look like:",
                      sorted(durham["voted_pct_lbl"].unique())[:15], "- send this to Claude")
                continue
            d["voted_pct_lbl"] = d["voted_pct_lbl"].str.replace(r"[^0-9]", "", regex=True) \
                                                .map({"5549": "55-49", "5511": "55-11"})
            d.to_csv(out, index=False)
        d = pd.read_csv(out, dtype=str, keep_default_na=False)
        prov_ids |= set(d["voter_reg_num"]) - {""}
        prov_names |= set(zip(d["full_name"].map(last_of), d["full_name"].map(first_of)))
        print(f"{year}: {len(d)} provisional ballots cast in 55-49 + 55-11 "
              f"{d['voted_pct_lbl'].value_counts().to_dict()}")

    # ---- 2. voter history: who voted in NCCU precincts each general --------
    out = f"{OUT}/vhis_nccu_generals.csv"
    if not os.path.exists(out):
        dates = {f"{d[4:6]}/{d[6:]}/{d[:4]}" for d in ELECTIONS.values()}
        h = read_tab(unzip_first(fetch(DURHAM_HIST_URL, f"{RAW}/ncvhis32.zip")),
                     keep=lambda c: c["election_lbl"].isin(dates)
                     & is_nccu(c["pct_label"] if "pct_label" in c else c["vtd_label"]))
        h.to_csv(out, index=False)
    h = pd.read_csv(out, dtype=str, keep_default_na=False)
    print("Voters in NCCU precincts by general election:",
          h.groupby("election_lbl")["voter_reg_num"].nunique().to_dict())
    print("  voting methods:", h["voting_method"].value_counts().to_dict())

    # ---- 3. current Durham registration for everyone above -----------------
    out = f"{OUT}/reg_current_nccu_related.csv"
    if not os.path.exists(out):
        wanted = prov_ids | set(h["voter_reg_num"])
        reg = read_tab(unzip_first(fetch(DURHAM_REG_URL, f"{RAW}/ncvoter32.zip")),
                       keep=lambda c: is_nccu(c["precinct_abbrv"])
                       | c["voter_reg_num"].isin(wanted)
                       | pd.Series([(norm(l), (norm(f).split() or [""])[0]) in prov_names
                                    for l, f in zip(c["last_name"], c["first_name"])], index=c.index)
                       | c["res_street_address"].str.upper().str.replace(r"\s+", " ", regex=True)
                                                .str.startswith("1801 FAYETTEVILLE"))
        cols = ["voter_reg_num", "ncid", "last_name", "first_name", "status_cd",
                "voter_status_desc", "voter_status_reason_desc",
                "res_street_address", "mail_addr1", "mail_addr2", "mail_city",
                "mail_state", "birth_year", "registr_dt", "precinct_abbrv"]
        reg[[c for c in cols if c in reg]].to_csv(out, index=False)
    reg = pd.read_csv(out, dtype=str, keep_default_na=False)
    print(f"Current Durham records saved: {len(reg)}")
    print("  statuses:", reg["voter_status_desc"].value_counts().to_dict())
    print("  (provisional voters are matched to these records by name + number in nccu_answers.R)")
