# =============================================================================
# 01_get_ncsbe_data.R — download NCSBE files and cut them down to the two
# NCCU precincts (Durham 55-11 and 55-49)
# =============================================================================
# Run ONCE per data refresh (snapshots are several GB each; budget time + disk).
# Works on Mac/Linux/Colab (needs the `unzip`, `iconv`, and `awk` command-line
# tools, which ship with macOS). Outputs land in data/processed/:
#   prov_<year>_nccu.csv      provisional ballots cast or registered in NCCU precincts
#   snapshot_<year>_nccu.csv  election-day registration snapshot, NCCU precincts
#   reg_current_nccu.csv      current Durham registration file, NCCU precincts
#   vhis_nccu.csv             Durham voter history rows voted in NCCU precincts
# Re-running skips anything that already exists; delete a file to rebuild it.

source("R/00_setup.R")
options(timeout = 60 * 60)   # big files

download_once <- function(url, dest) {
  if (!file.exists(dest)) {
    message("Downloading ", basename(url), " ...")
    download.file(url, dest, mode = "wb", quiet = FALSE)
  }
  dest
}

# NCSBE text files are usually UTF-16LE (starts with bytes FF FE), sometimes UTF-8.
is_utf16 <- function(path, zipped = FALSE) {
  if (zipped) {
    con <- pipe(sprintf("unzip -p '%s' | head -c 2", path), "rb")
  } else {
    con <- file(path, "rb")
  }
  on.exit(close(con))
  b <- readBin(con, "raw", 2)
  length(b) == 2 && b[1] == as.raw(0xFF) && b[2] == as.raw(0xFE)
}

# Stream a (possibly zipped, possibly UTF-16) tab file and keep only the header
# plus rows in Durham NCCU precincts. `pct_cols` = precinct columns to test;
# a row is kept if ANY of them is one of NCCU_PRECINCTS.
extract_nccu <- function(path, zipped, pct_cols, county_col = "county_id", out) {
  if (file.exists(out)) return(invisible(out))
  cat_cmd  <- if (zipped) sprintf("unzip -p '%s'", path) else sprintf("cat '%s'", path)
  conv_cmd <- if (is_utf16(path, zipped)) "iconv -f UTF-16 -t UTF-8" else "iconv -f LATIN1 -t UTF-8"
  pcts     <- paste(NCCU_PRECINCTS, collapse = "|")
  awk <- sprintf(
    paste0("awk -F'\\t' 'NR==1{for(i=1;i<=NF;i++){h=$i;gsub(/[ \\r\"]/,\"\",h);col[h]=i};print;next}",
           "{c=$col[\"%s\"];gsub(/[ \"]/,\"\",c);if(c!=\"%s\")next;",
           "keep=0;split(\"%s\",pc,\" \");for(k in pc){p=$col[pc[k]];gsub(/[ \"]/,\"\",p);if(p~/^(%s)$/)keep=1};",
           "if(keep)print}'"),
    county_col, DURHAM_COUNTY_ID, paste(pct_cols, collapse = " "), pcts)
  cmd <- paste(cat_cmd, "|", conv_cmd, "|", "tr -d '\\r'", "|", awk)
  message("Filtering ", basename(path), " to NCCU precincts ...")
  dt <- data.table::fread(cmd = cmd, sep = "\t", colClasses = "character",
                          quote = "", fill = TRUE, strip.white = FALSE)
  names(dt) <- trimws(names(dt))
  readr::write_csv(dt, out)
  message("  -> ", nrow(dt), " rows written to ", out)
  invisible(out)
}

# ---- 1. Provisional ballot files, one per general election -----------------
for (i in seq_len(nrow(ELECTIONS))) {
  e    <- ELECTIONS[i, ]
  dest <- file.path(DIR_RAW, basename(e$prov_url))
  ok   <- tryCatch({ download_once(e$prov_url, dest); TRUE },
                   error = function(err) { message("!! ", e$year, " provisional: ", conditionMessage(err),
                                                   "\n   Find the right URL on dl.ncsbe.gov/ENRS/ and update ELECTIONS."); FALSE })
  if (ok) extract_nccu(dest, zipped = grepl("\\.zip$", dest),
                       pct_cols = c("reg_pct_lbl", "voted_pct_lbl"),
                       out = file.path(DIR_PROCESSED, sprintf("prov_%d_nccu.csv", e$year)))
}

# ---- 2. Election-day registration snapshots ---------------------------------
# These are the backbone of the over-time work: who was registered in the NCCU
# precincts on election day, their age, status (verified / unverified / pending /
# inactive-undeliverable), and their mailing address.
for (i in seq_len(nrow(ELECTIONS))) {
  e    <- ELECTIONS[i, ]
  dest <- file.path(DIR_RAW, basename(e$snapshot_url))
  ok   <- tryCatch({ download_once(e$snapshot_url, dest); TRUE },
                   error = function(err) { message("!! ", e$year, " snapshot: ", conditionMessage(err)); FALSE })
  if (ok) extract_nccu(dest, zipped = TRUE, pct_cols = "precinct_abbrv",
                       out = file.path(DIR_PROCESSED, sprintf("snapshot_%d_nccu.csv", e$year)))
}

# ---- 3. Current Durham registration + voter history -------------------------
reg_zip  <- download_once(CURRENT_REG_URL,  file.path(DIR_RAW, "ncvoter32.zip"))
hist_zip <- download_once(CURRENT_HIST_URL, file.path(DIR_RAW, "ncvhis32.zip"))

extract_nccu(reg_zip, zipped = TRUE, pct_cols = "precinct_abbrv",
             out = file.path(DIR_PROCESSED, "reg_current_nccu.csv"))

# Current Durham file, ALL precincts, slim columns: used to see whether 2024 NCCU
# provisional voters are still registered anywhere in Durham.
durham_all_out <- file.path(DIR_PROCESSED, "reg_current_durham_slim.csv")
if (!file.exists(durham_all_out)) {
  conv <- if (is_utf16(reg_zip, TRUE)) "iconv -f UTF-16 -t UTF-8" else "iconv -f LATIN1 -t UTF-8"
  dt <- data.table::fread(cmd = sprintf("unzip -p '%s' | %s | tr -d '\\r'", reg_zip, conv),
                          sep = "\t", colClasses = "character", quote = "", fill = TRUE,
                          select = c("voter_reg_num", "ncid", "status_cd", "voter_status_desc",
                                     "voter_status_reason_desc", "res_street_address", "mail_addr1",
                                     "mail_addr2", "mail_city", "mail_state", "registr_dt",
                                     "birth_year", "precinct_abbrv"))
  readr::write_csv(dt, durham_all_out)
}

# Voter history: keep rows where the ballot was cast in an NCCU precinct
extract_nccu(hist_zip, zipped = TRUE, pct_cols = c("pct_label", "vtd_label"),
             out = file.path(DIR_PROCESSED, "vhis_nccu.csv"))

# ---- 4. (Optional) statewide file to catch re-registration in other counties --
# ~1 GB zipped. Uncomment when you're ready for Q1's "re-registered elsewhere" step.
# state_zip <- download_once(STATEWIDE_REG_URL, file.path(DIR_RAW, "ncvoter_Statewide.zip"))
# dt <- data.table::fread(cmd = sprintf("unzip -p '%s' | iconv -f LATIN1 -t UTF-8", state_zip),
#                         sep = "\t", colClasses = "character", quote = "", fill = TRUE,
#                         select = c("county_desc", "voter_reg_num", "ncid", "status_cd",
#                                    "voter_status_reason_desc", "registr_dt", "birth_year"))
# readr::write_csv(dt, file.path(DIR_PROCESSED, "reg_current_statewide_slim.csv"))

message("Done. Files in ", DIR_PROCESSED, ":")
print(list.files(DIR_PROCESSED))
