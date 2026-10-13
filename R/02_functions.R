# =============================================================================
# 02_functions.R — load + standardize the NCCU extracts, classify addresses
# =============================================================================
source("R/00_setup.R")

squish_up <- function(x) str_to_upper(str_squish(dplyr::coalesce(as.character(x), "")))

read_chr <- function(path) {
  d <- readr::read_csv(path, col_types = readr::cols(.default = "c"),
                       na = character(), show_col_types = FALSE)
  names(d) <- str_trim(names(d))
  d
}

# Prefer the new pipeline file; fall back to the files already in the repo.
find_file <- function(...) {
  cands <- file.path(DIR_PROCESSED, c(...))
  hit <- cands[file.exists(cands)]
  if (length(hit)) hit[1] else NA_character_
}

# ---- Provisional ballots ------------------------------------------------------
load_provisional <- function(year) {
  legacy <- if (year == 2024) "nccu_prov_24.csv" else character()
  path <- find_file(sprintf("prov_%d_nccu.csv", year), legacy)
  if (is.na(path)) return(NULL)
  read_chr(path) |>
    mutate(across(everything(), squish_up)) |>
    filter(county_id == DURHAM_COUNTY_ID | county_name == "DURHAM") |>
    filter(reg_pct_lbl %in% NCCU_PRECINCTS | voted_pct_lbl %in% NCCU_PRECINCTS) |>
    transmute(
      year            = year,
      voter_reg_num,
      precinct        = if_else(voted_pct_lbl %in% NCCU_PRECINCTS, voted_pct_lbl, reg_pct_lbl),
      res_addr_street,
      on_campus_addr  = str_starts(res_addr_street, NCCU_STREET),
      reason          = pv_voted_reason,
      reason_group    = group_prov_reason(pv_voted_reason),
      status          = pv_status,
      outcome         = case_when(
        status %in% c("APPROVED", "COUNTED")               ~ "Counted",
        str_detect(status, "PARTIAL")                     ~ "Partially counted",
        str_detect(status, "NOT COUNTED|DENIED|REJECT")   ~ "Not counted",
        TRUE                                              ~ "Other / unknown"),
      not_counted_reason
    )
}

group_prov_reason <- function(r) {
  case_when(
    str_detect(r, "NO RECORD")                    ~ "No record of registration",
    str_detect(r, "REMOVED")                      ~ "Previously removed",
    str_detect(r, "PRECINCT|COUNTY")              ~ "Wrong precinct / county",
    str_detect(r, "ADDRESS|GEOCODE|MOVED")        ~ "Address problem",
    str_detect(r, "\\bID\\b|IDENTIF|HAVA")        ~ "Photo ID",
    str_detect(r, "ALREADY VOTED")                ~ "Already voted",
    r == ""                                       ~ "Not recorded",
    TRUE                                          ~ "Other"
  )
}

# ---- Registration status grouping --------------------------------------------
# Collapses NCSBE status reasons into the categories the PI cares about.
group_reg_status <- function(status_cd, reason) {
  case_when(
    status_cd == "A" & reason == "VERIFIED"                          ~ "Active - verified",
    status_cd == "A" & str_detect(reason, "UNVERIFIED")              ~ "Active - unverified",
    status_cd == "A" & str_detect(reason, "PENDING")                 ~ "Active - pending verification/confirmation",
    status_cd == "I" & str_detect(reason, "UNDELIVERABLE")           ~ "Inactive - mail returned undeliverable",
    status_cd == "I" & str_detect(reason, "NOT RETURNED")            ~ "Inactive - confirmation not returned",
    status_cd == "I" & str_detect(reason, "DL/SSN")                  ~ "Inactive - DL/SSN update needed",
    status_cd %in% c("R", "D")                                       ~ "Removed / denied",
    TRUE                                                             ~ "Other"
  )
}

# ---- Address classification (PI question 2) ----------------------------------
# NCSBE leaves the mailing fields blank when mail goes to the residential
# address, so the *effective* mailing address = mailing fields if present,
# otherwise the residential address (+ unit, if the record has one).
DORM_PATTERN <- paste0("HALL|LANDING|TOWER|ROOM|\\bRM\\b|APT|#|UNIT|SUITE|STE\\b|",
                       "EAGLESON|CHIDLEY|BAYNES|MCLEAN|RUSH|ANNIE DAY|SHEPARD|LAWSON|",
                       "\\bBOX\\b|CAMPUS|NCCU|CENTRAL UNIV")

classify_mailing <- function(mail1, mail2, mail_city, mail_state, res_street, res_unit = "") {
  mail1 <- squish_up(mail1); mail2 <- squish_up(mail2)
  city  <- squish_up(mail_city); st <- squish_up(mail_state)
  res   <- squish_up(res_street); unit <- squish_up(res_unit)
  uses_res <- mail1 == ""
  eff1 <- if_else(uses_res, res, mail1)
  eff2 <- if_else(uses_res, unit, mail2)
  is_1801 <- str_detect(eff1, "^1801 FAYET+E?VILLE")
  is_pobox <- str_detect(paste(eff1, eff2), "\\bP\\.?\\s?O\\.?\\s?BOX\\b|^POB\\b|^BOX\\b")
  has_detail <- eff2 != "" | str_detect(eff1, DORM_PATTERN) |
                str_detect(eff1, "^1801 FAYET+E?VILLE (ST|STREET|RD|AVE)?\\.?\\s+\\S")
  case_when(
    is_pobox                               ~ "PO Box",
    is_1801 & !has_detail                  ~ "Bare 1801 Fayetteville St",
    is_1801 & has_detail                   ~ "1801 Fayetteville + dorm/room",
    !uses_res & st != "" & st != "NC"      ~ "Out-of-state (home) address",
    !uses_res & city != "" & city != "DURHAM" ~ "Elsewhere in NC (home) address",
    str_detect(eff1, DORM_PATTERN)         ~ "1801 Fayetteville + dorm/room",
    TRUE                                   ~ "Other Durham street address"
  )
}

MAIL_LEVELS <- c("Bare 1801 Fayetteville St", "1801 Fayetteville + dorm/room",
                 "PO Box", "Other Durham street address",
                 "Elsewhere in NC (home) address", "Out-of-state (home) address")

# ---- Snapshots + current registration ----------------------------------------
# Returns one standardized row per registrant in the NCCU precincts.
standardize_registration <- function(d, as_of_year, nccu_only = TRUE) {
  has <- function(col) col %in% names(d)
  g   <- function(col) if (has(col)) squish_up(d[[col]]) else rep("", nrow(d))
  res_street <- if (has("res_street_address")) g("res_street_address") else
    str_squish(paste(g("house_num"), g("half_code"), g("street_dir"), g("street_name"),
                     g("street_type_cd"), g("street_sufx_cd")))
  res_unit <- str_squish(paste(g("unit_designator"), g("unit_num")))
  age <- if (has("age_at_year_end")) as.integer(g("age_at_year_end")) else
         if (has("birth_year") && any(g("birth_year") != "")) as_of_year - as.integer(g("birth_year")) else
         as.integer(g("age"))
  tibble(
    as_of        = as_of_year,
    voter_reg_num = g("voter_reg_num"),
    ncid         = g("ncid"),
    precinct     = g("precinct_abbrv"),
    status_cd    = g("status_cd"),
    status_reason = g("voter_status_reason_desc"),
    status_group = group_reg_status(status_cd, status_reason),
    age          = age,
    youth        = age %in% YOUTH_AGES,
    registr_dt   = g("registr_dt"),
    res_street   = res_street,
    on_campus    = str_starts(res_street, NCCU_STREET),
    mail_class   = factor(classify_mailing(g("mail_addr1"), g("mail_addr2"), g("mail_city"),
                                           g("mail_state"), res_street, res_unit),
                          levels = MAIL_LEVELS)
  ) |>
    filter(!nccu_only | precinct %in% NCCU_PRECINCTS)
}

load_snapshot <- function(year) {
  legacy <- if (year == 2024) "snapshot_24_nccu.csv" else character()
  path <- find_file(sprintf("snapshot_%d_nccu.csv", year), legacy)
  if (is.na(path)) return(NULL)
  standardize_registration(read_chr(path), year)
}

load_current_reg <- function() {
  path <- find_file("reg_current_nccu.csv", "reg_26_nccu.csv")
  if (is.na(path)) return(NULL)
  standardize_registration(read_chr(path), 2026)
}

# Durham-wide current file (all precincts) if 01_get_ncsbe_data.R has built it;
# otherwise only the NCCU-precinct file is available — say so in outputs.
load_current_durham <- function() {
  path <- find_file("reg_current_durham_slim.csv")
  if (is.na(path)) return(list(data = load_current_reg(), scope = "NCCU precincts only"))
  list(data = standardize_registration(read_chr(path), 2026, nccu_only = FALSE),
       scope = "All of Durham County")
}

# Unverifiable-address files (from Carter / NextRequest). Drop CSV or XLSX files
# into data/raw/unverified/. Column names vary, so we sniff for them.
load_unverified <- function() {
  files <- list.files(DIR_UNVERIF, pattern = "\\.(csv|txt|tsv)$", full.names = TRUE)
  if (!length(files)) return(NULL)
  purrr_map <- function(f) {
    d <- data.table::fread(f, colClasses = "character")
    names(d) <- tolower(str_replace_all(trimws(names(d)), "[^A-Za-z0-9]+", "_"))
    pick <- function(pat) { hit <- grep(pat, names(d), value = TRUE); if (length(hit)) d[[hit[1]]] else "" }
    tibble(file = basename(f),
           voter_reg_num = squish_up(pick("reg_num|regnum|registration")),
           ncid = squish_up(pick("^ncid")),
           address = squish_up(pick("res.*addr|street|address")),
           precinct = squish_up(pick("precinct|pct")),
           file_date = squish_up(pick("date")))
  }
  bind_rows(lapply(files, purrr_map))
}
