# NCCU Campus Portrait — Work Plan (Fall 2026)

**Urgent ask from the PI:** a clear picture of unverifiable voter registrations and
provisional balloting at NCCU over the last 3–4 general elections (ideally 2016 →
2024), with a couple of visuals ready **by next Friday** to support NCCU staff,
administration, and faculty. The full portrait can come later; the *unverified*
piece is the priority.

Study area: Durham County precincts **55-11 and 55-49** (together they cover every
NCCU dorm). With no student lists, "students" = registrants/voters **aged 18–25**
in those two precincts.

---

## The four questions → what answers each

| # | PI question | Script | Data needed | Status |
|---|---|---|---|---|
| 1 | Of NCCU's 2024 provisional voters, who is still registered in Durham? Did any re-register? Is that registration solid, or back in unverified status? Any pending rejections at 1801 Fayetteville in the latest unverified file? | `R/10_q1_provisional_followup.R` | 2024 provisional file, 2024 snapshot, **current Durham file (all precincts)**, optional statewide file, **latest unverifiable-address file** | Runs on 55-49 only; needs 55-11 + Durham-wide + unverified file |
| 2 | Is "bare 1801 Fayetteville St" the problem? Do verified registrants have better addresses (dorm + room, or a home address) than unverified ones? | `R/11_q2_address_1801.R` | Election-day snapshots 2016–2024 + current file | Runs on 55-49, 2024 + 2026 |
| 3 | Can we link unverified status to provisional voting at NCCU, over time? | `R/12_q3_unverified_provisional_link.R` | Provisional files + snapshots 2016–2024, voter history, unverified files | 2024 only so far |
| — | Context: provisionals cast/thrown vs. 18–25-year-olds voting successfully, each election | same as Q3 (`q3_nccu_campus_portrait_by_year.csv`) | Voter history `ncvhis32` + snapshots | Needs download |

---

## Step-by-step (in order)

### This week
1. **Set up R.** Open the repo in RStudio, run `source("R/00_setup.R")` (installs packages).
2. **Get the data** — run `source("R/01_get_ncsbe_data.R")` on a laptop with ~25 GB free
   or in Colab. It downloads, for 2016/2018/2020/2022/2024: the provisional file and the
   election-day snapshot, plus the current Durham registration (`ncvoter32`) and
   history (`ncvhis32`), and cuts each to precincts 55-11 + 55-49.
   - If a URL 404s, find the right file on <https://dl.ncsbe.gov/> (folders `ENRS/` and
     `data/Snapshots/`) and fix the `ELECTIONS` table in `00_setup.R`. Older provisional
     files may be zipped or named differently.
   - **Check precinct boundaries.** 55-11 and 55-49 may have been redrawn since 2016.
     Confirm on the Durham BOE precinct maps that both contained NCCU dorms in each year.
3. **Get Carter's unverifiable-address files** (the one with the 440 students at 1801
   Fayetteville, plus the most recent one). Save them as CSV in `data/raw/unverified/`.
   The scripts pick them up automatically.
4. **Run everything:** `source("R/run_all.R")`. Tables → `output/tables/`, figures →
   `output/figures/`.
5. **Hand-check the address categories:** open
   `data/derived/q2_address_classification_spotcheck.csv` and confirm each row is in the
   right bucket. Fix `DORM_PATTERN` in `R/02_functions.R` if dorm names are missed.

### For Friday (the unverified visuals)
6. Figure 1 — **Q2 address chart** (`q2_mailing_address_by_status.png`), all years.
7. Figure 2 — **Q3 portrait**: provisionals cast / not counted per election next to the
   number of 18–25 registrants who were unverified or undeliverable (`q3a`, `q3c`).
8. A one-page note with the headline numbers from `q1_headline.csv`, `q2_headline.csv`,
   `q3_nccu_campus_portrait_by_year.csv`, and the caveats below.

### After Friday (campus portrait + mapping)
9. Statewide file → finish Q1's "re-registered in another county" check (by NCID).
10. Q3 over time with all unverified files: for each file date, how many 1801 records
    later cast provisionals, and how those ballots fared.
11. Fold NCCU into the broader 12-campus provisional work and the mapping project.

---

## Preliminary results (precinct 55-49 only — treat as a first look)

**Q1.** 19 provisional ballots were cast in 55-49 in Nov 2024: 14 counted, 1 partially
counted, 4 not counted. In the Oct 2026 file, 7 of the 19 are active and verified, 6
are inactive (3 mail returned undeliverable, 3 confirmation not returned), and 6 are
not in the 55-49 file at all — they may have moved precincts or been removed; the
Durham-wide and statewide files will tell us which. 6 of the 19 were not on the
election-day rolls at all ("no record of registration" / "previously removed").

Across all 1801 Fayetteville registrants today: 44% active-verified, 10% pending,
2% unverified, and 44% inactive (20% confirmation not returned, 12% undeliverable,
12% DL/SSN update needed).

**Q2 — the address question is more complicated than "bare 1801 = unverified".**
- On Election Day 2024, **49% of *verified* registrants gave only the bare 1801
  Fayetteville address**, so a bare address does not by itself prevent verification.
- The **unverified and pending** group was ~86% *dorm + room* addresses — but these are
  overwhelmingly people who registered in fall 2024 and hadn't been processed yet, so
  registration timing is a confounder. See
  `q2_mailing_address_by_status_and_reg_timing.csv`.
- **PO boxes:** 40% of 2024 "mail returned undeliverable" registrants (111 of 280)
  listed a PO Box — consistent with NCCU administrators saying there are no PO boxes
  anymore. Old campus boxes may be a real, fixable source of undeliverable mail.
- In the 2026 file, 58% of undeliverable registrants list **a dorm and room**. Students
  change rooms every year, so last year's room may bounce. Worth raising with NCCU.

These are first-pass numbers from one precinct. The PI's 440 unverified students and
precinct 55-11 aren't in yet.

---

## Caveats to state in anything public
- "Students" = registrants aged 18–25 in 55-11/55-49. Some aren't students; some
  students live off campus or are older.
- "Voted successfully" comes from voter history, which drops people later removed
  from the rolls, so older elections are undercounted.
- Unverified ≠ removed. The status categories mean different things; keep them
  separate (lumping "pending" with "undeliverable" hides opposite patterns).
- Small numbers (e.g., 19 provisionals) → report counts, not just percentages.

## Questions to ask the PI / team
1. Which file is "Carter's research" — can we get it (and earlier versions) as CSV?
2. Should the Q1 count use where the ballot was **cast** or where the voter was
   **registered**? (Scripts currently include both.)
3. Precinct boundary history for 55-11/55-49 since 2016?
4. Is it OK for the repo to stay public? (see Data privacy below)

## Data privacy
The voter files are public records, but this repo contains names, home addresses, and
phone numbers of NCCU students. Recommend making the GitHub repo **private** or
removing `data/processed/*.csv` from git history. New raw and person-level files are
git-ignored (`data/raw/`, `data/derived/`); only aggregate tables and figures in
`output/` are meant to be shared.
