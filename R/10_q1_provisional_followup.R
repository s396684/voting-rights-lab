# =============================================================================
# Q1 — What happened to NCCU's 2024 provisional voters?
#   * Are they still registered in Durham? Did any re-register?
#   * If they re-registered, is the registration solid (verified) or did it end
#     up back in unverified / pending / undeliverable status?
#   * Are there pending verifications/rejections at 1801 Fayetteville St right now?
# =============================================================================
source("R/02_functions.R")
dir.create("data/derived", showWarnings = FALSE)   # person-level files (git-ignored)

prov24  <- load_provisional(2024)
snap24  <- load_snapshot(2024)
cur     <- load_current_durham()
reg_now <- cur$data
precincts_in_prov <- sort(unique(prov24$precinct))

# ---- Link each 2024 provisional voter to election-day + current registration --
q1 <- prov24 |>
  left_join(snap24 |> select(voter_reg_num, ncid, age_2024 = age,
                             status_2024 = status_group, mail_2024 = mail_class),
            by = "voter_reg_num") |>
  left_join(reg_now |> select(voter_reg_num, ncid_now = ncid, status_now = status_group,
                              status_reason_now = status_reason, precinct_now = precinct,
                              mail_now = mail_class, registr_dt_now = registr_dt),
            by = "voter_reg_num") |>
  mutate(
    in_snapshot_2024 = !is.na(status_2024),
    current_status   = coalesce(status_now,
                                paste0("Not in current file (", cur$scope, ")")),
    solid_now        = current_status == "Active - verified",
    shaky_now        = str_detect(current_status, "unverified|pending|undeliverable|not returned|DL/SSN")
  )

# Optional: re-registration in ANOTHER county (needs the statewide file; see 01_)
statewide_path <- file.path(DIR_PROCESSED, "reg_current_statewide_slim.csv")
if (file.exists(statewide_path)) {
  sw <- read_chr(statewide_path) |> mutate(across(everything(), squish_up))
  q1 <- q1 |>
    left_join(sw |> filter(ncid != "") |> group_by(ncid) |>
                summarise(counties_now = paste(sort(unique(county_desc)), collapse = "; "),
                          .groups = "drop"),
              by = "ncid")
}

# Optional: are any of them in the latest unverifiable-address file?
unv <- load_unverified()
if (!is.null(unv)) {
  q1 <- q1 |> mutate(in_unverified_file =
                       voter_reg_num %in% unv$voter_reg_num | (ncid != "" & ncid %in% unv$ncid))
}

readr::write_csv(q1, "data/derived/q1_prov2024_followup_person_level.csv")

# ---- Summary tables --------------------------------------------------------------
q1_summary <- q1 |>
  count(outcome_2024 = outcome, current_status, name = "voters") |>
  arrange(outcome_2024, desc(voters))
readr::write_csv(q1_summary, file.path(DIR_TABLES, "q1_prov2024_current_status.csv"))

q1_headline <- q1 |>
  summarise(
    provisional_voters_2024   = n(),
    counted                   = sum(outcome == "Counted"),
    partially_counted         = sum(outcome == "Partially counted"),
    not_counted               = sum(outcome == "Not counted"),
    not_in_current_file       = sum(is.na(status_now)),
    active_verified_now       = sum(solid_now),
    unverified_pending_or_inactive_now = sum(shaky_now & !is.na(status_now)),
    gave_bare_1801_in_2024    = sum(mail_2024 == "Bare 1801 Fayetteville St", na.rm = TRUE),
    current_file_scope        = cur$scope
  )
readr::write_csv(q1_headline, file.path(DIR_TABLES, "q1_headline.csv"))
print(q1_headline)

# ---- Pending verifications at 1801 Fayetteville RIGHT NOW --------------------------
pending_1801 <- reg_now |>
  filter(on_campus) |>
  count(status_group, name = "registrants") |>
  mutate(share = registrants / sum(registrants))
readr::write_csv(pending_1801, file.path(DIR_TABLES, "q1_1801_current_status.csv"))

if (!is.null(unv)) {
  unv_1801 <- unv |>
    mutate(is_1801 = str_detect(address, "1801 FAYET")) |>
    count(file, is_1801, name = "records")
  readr::write_csv(unv_1801, file.path(DIR_TABLES, "q1_unverified_file_1801.csv"))
}

# ---- Figure: where are 2024 provisional voters now? -------------------------------
fig_q1 <- q1 |>
  count(current_status, outcome) |>
  mutate(current_status = fct_reorder(current_status, n, .fun = sum),
         outcome = factor(outcome, levels = c("Counted", "Partially counted", "Not counted", "Other / unknown"))) |>
  ggplot(aes(x = n, y = current_status, fill = outcome)) +
  geom_col(width = 0.65, color = "#fcfcfb", linewidth = 0.5) +
  scale_fill_manual(values = c("Counted" = PAL[["blue"]], "Partially counted" = PAL[["yellow"]],
                               "Not counted" = PAL[["orange"]], "Other / unknown" = PAL[["gray"]]),
                    name = "2024 provisional outcome") +
  scale_x_continuous(breaks = scales::breaks_pretty(), expand = expansion(mult = c(0, .05))) +
  labs(title = "Where are NCCU's 2024 provisional voters now?",
       subtitle = sprintf("Registration status today of the %d people who cast a provisional ballot in NCCU precinct(s) %s, Nov. 2024",
                          nrow(q1), paste(precincts_in_prov, collapse = " & ")),
       x = "Voters", y = NULL,
       caption = str_wrap(paste0("Current status from the ", cur$scope, " registration file. ", SOURCE_NOTE), 150)) +
  theme_lab() +
  theme(panel.grid.major.x = element_line(color = "#e6e5e0", linewidth = 0.3),
        panel.grid.major.y = element_blank())
save_fig(fig_q1, "q1_prov2024_where_now", width = 10, height = 5)
