# =============================================================================
# Q3 + campus portrait — Linking unverified registrations to provisional voting
# at NCCU over time, in the context of how many young people voted successfully.
#
# For every general election with data (2016-2024):
#   * 18-25 registrants in 55-11 + 55-49 on election day, by registration status
#   * 18-25 voters in those precincts (voter history) = proxy for students who
#     voted successfully (no student lists)
#   * provisional ballots cast / counted / partially counted / not counted, and why
#   * each provisional voter's registration status ON ELECTION DAY — the link
#     between unverifiability and provisional voting
# =============================================================================
source("R/02_functions.R")

years <- ELECTIONS$year

# ---- Voter history (successful voters), if downloaded ---------------------------
vhis_path <- find_file("vhis_nccu.csv")
vhis <- if (!is.na(vhis_path)) {
  read_chr(vhis_path) |>
    mutate(across(everything(), squish_up),
           elec_date = as.Date(election_lbl, "%m/%d/%Y"),
           year = as.integer(format(elec_date, "%Y"))) |>
    filter(format(elec_date, "%m") == "11", year %in% years)
} else NULL

per_year <- lapply(years, function(y) {
  snap <- load_snapshot(y)
  prov <- load_provisional(y)
  if (is.null(snap) && is.null(prov)) return(NULL)

  # Provisional voters linked to election-day registration status
  prov_linked <- if (!is.null(prov)) {
    prov |>
      left_join(snap |> select(voter_reg_num, age, status_group, mail_class), by = "voter_reg_num") |>
      mutate(status_on_election_day = coalesce(status_group, "Not on election-day rolls"))
  } else NULL

  youth_voted <- if (!is.null(vhis) && !is.null(snap)) {
    vhis |> filter(year == y) |> distinct(voter_reg_num) |>
      inner_join(snap |> filter(youth) |> select(voter_reg_num), by = "voter_reg_num") |> nrow()
  } else NA_integer_

  list(
    summary = tibble(
      year = y,
      precincts_in_data         = if (!is.null(snap)) paste(sort(unique(snap$precinct)), collapse = " & ") else NA,
      registrants_all           = if (!is.null(snap)) nrow(snap) else NA,
      registrants_18_25         = if (!is.null(snap)) sum(snap$youth) else NA,
      youth_unverified_pending  = if (!is.null(snap)) sum(snap$youth & str_detect(snap$status_group, "unverified|pending")) else NA,
      youth_inactive_undeliv    = if (!is.null(snap)) sum(snap$youth & str_detect(snap$status_group, "undeliverable")) else NA,
      youth_voted_successfully  = youth_voted,
      prov_cast                 = if (!is.null(prov)) nrow(prov) else NA,
      prov_counted              = if (!is.null(prov)) sum(prov$outcome == "Counted") else NA,
      prov_partial              = if (!is.null(prov)) sum(prov$outcome == "Partially counted") else NA,
      prov_not_counted          = if (!is.null(prov)) sum(prov$outcome == "Not counted") else NA,
      prov_voters_18_25         = if (!is.null(prov_linked)) sum(prov_linked$age %in% YOUTH_AGES) else NA,
      prov_unverified_or_pending_on_eday = if (!is.null(prov_linked))
        sum(str_detect(prov_linked$status_on_election_day, "unverified|pending|undeliverable")) else NA,
      prov_not_on_rolls_eday    = if (!is.null(prov_linked))
        sum(prov_linked$status_on_election_day == "Not on election-day rolls") else NA
    ),
    reasons = if (!is.null(prov)) count(prov, year, reason_group, outcome, name = "ballots") else NULL,
    link    = if (!is.null(prov_linked)) count(prov_linked, year, status_on_election_day, outcome, name = "ballots") else NULL,
    youth_status = if (!is.null(snap)) snap |> filter(youth) |> count(year = y, status_group, name = "registrants_18_25") else NULL
  )
})
per_year <- Filter(Negate(is.null), per_year)

portrait <- bind_rows(lapply(per_year, `[[`, "summary")) |>
  mutate(prov_throw_rate = (prov_not_counted + prov_partial) / prov_cast,
         prov_per_100_youth_voters = 100 * prov_cast / youth_voted_successfully)
reasons      <- bind_rows(lapply(per_year, `[[`, "reasons"))
link         <- bind_rows(lapply(per_year, `[[`, "link"))
youth_status <- bind_rows(lapply(per_year, `[[`, "youth_status"))

readr::write_csv(portrait,     file.path(DIR_TABLES, "q3_nccu_campus_portrait_by_year.csv"))
readr::write_csv(reasons,      file.path(DIR_TABLES, "q3_provisional_reasons_by_year.csv"))
readr::write_csv(link,         file.path(DIR_TABLES, "q3_provisional_by_eday_status.csv"))
readr::write_csv(youth_status, file.path(DIR_TABLES, "q3_youth_registration_status_by_year.csv"))
print(portrait, width = Inf)

# ---- Unverifiable-address files: overlap with provisional voters -------------------
unv <- load_unverified()
if (!is.null(unv)) {
  all_prov <- bind_rows(lapply(years, load_provisional))
  overlap <- unv |>
    group_by(file) |>
    summarise(records = n(),
              at_1801 = sum(str_detect(address, "1801 FAYET")),
              matched_to_any_nccu_provisional = sum(voter_reg_num %in% all_prov$voter_reg_num),
              .groups = "drop")
  readr::write_csv(overlap, file.path(DIR_TABLES, "q3_unverified_files_overlap.csv"))
  print(overlap)
}

# ---- Figures --------------------------------------------------------------------------
outcome_cols <- c("Counted" = PAL[["blue"]], "Partially counted" = PAL[["yellow"]],
                  "Not counted" = PAL[["orange"]], "Other / unknown" = PAL[["gray"]])

# (a) Provisional ballots by outcome, by election
fig_a <- link |>
  group_by(year, outcome) |> summarise(ballots = sum(ballots), .groups = "drop") |>
  mutate(outcome = factor(outcome, levels = names(outcome_cols))) |>
  ggplot(aes(x = factor(year), y = ballots, fill = outcome)) +
  geom_col(width = 0.6, color = "#fcfcfb", linewidth = 0.5) +
  geom_text(data = portrait, inherit.aes = FALSE,
            aes(x = factor(year), y = prov_cast,
                label = paste0(prov_cast, " cast\n", prov_not_counted + prov_partial, " not fully counted")),
            vjust = -0.3, size = 3.3, color = "#52514e", lineheight = 0.95) +
  scale_fill_manual(values = outcome_cols, name = NULL) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(title = "Provisional ballots in NCCU precincts, general elections",
       subtitle = paste("Precincts:", paste(unique(portrait$precincts_in_data), collapse = "; ")),
       x = NULL, y = "Provisional ballots", caption = SOURCE_NOTE) +
  theme_lab()
save_fig(fig_a, "q3a_nccu_provisionals_by_year", width = 8, height = 5.5)

# (b) Registration status of provisional voters on election day — the link
status_levels <- c("Active - verified", "Active - pending verification/confirmation",
                   "Active - unverified", "Inactive - mail returned undeliverable",
                   "Inactive - confirmation not returned", "Inactive - DL/SSN update needed",
                   "Not on election-day rolls", "Other")
status_cols <- setNames(c(PAL[["blue"]], PAL[["yellow"]], PAL[["orange"]], PAL[["red"]],
                          PAL[["magenta"]], PAL[["violet"]], PAL[["gray"]], "#c3c2b7"), status_levels)
fig_b <- link |>
  group_by(year, status_on_election_day) |> summarise(ballots = sum(ballots), .groups = "drop") |>
  mutate(status_on_election_day = factor(status_on_election_day, levels = status_levels)) |>
  ggplot(aes(x = factor(year), y = ballots, fill = status_on_election_day)) +
  geom_col(width = 0.6, color = "#fcfcfb", linewidth = 0.5) +
  scale_fill_manual(values = status_cols, name = NULL, drop = TRUE) +
  guides(fill = guide_legend(ncol = 2)) +
  labs(title = "How were NCCU provisional voters registered on Election Day?",
       subtitle = "Provisional voters in NCCU precincts, by their status in the election-day registration snapshot",
       x = NULL, y = "Provisional voters", caption = SOURCE_NOTE) +
  theme_lab()
save_fig(fig_b, "q3b_provisional_voters_eday_status", width = 9, height = 6)

# (c) 18-25 registrants by status over time
if (nrow(youth_status)) {
  fig_c <- youth_status |>
    mutate(status_group = factor(status_group, levels = status_levels)) |>
    ggplot(aes(x = factor(year), y = registrants_18_25, fill = status_group)) +
    geom_col(width = 0.6, color = "#fcfcfb", linewidth = 0.5) +
    scale_fill_manual(values = status_cols, name = NULL, drop = TRUE) +
    scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.05))) +
    guides(fill = guide_legend(ncol = 2)) +
    labs(title = "Registered 18-25-year-olds in NCCU precincts, by status",
         subtitle = "Election-day registration snapshots",
         x = NULL, y = "Registrants aged 18-25", caption = SOURCE_NOTE) +
    theme_lab()
  save_fig(fig_c, "q3c_youth_registrants_by_status", width = 9, height = 6)
}
