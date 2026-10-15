# =============================================================================
# nccu_answers.R  —  answers to Professor Peck's NCCU questions

for (p in c("dplyr", "tidyr", "readr", "stringr", "ggplot2", "forcats", "scales", "readxl")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
  library(p, character.only = TRUE)
}
dir.create("output", showWarnings = FALSE)

YOUTH <- 18:25                              # PI's proxy for students
PRECINCTS <- c("55-49", "55-11")
ELECTION_DATES <- c(`2016` = "11/08/2016", `2018` = "11/06/2018", `2020` = "11/03/2020",
                    `2022` = "11/08/2022", `2024` = "11/05/2024")
SOURCE <- "Source: NC State Board of Elections (provisional, voter history, registration files). Student Voting Rights Lab, Duke."

# ---- helpers ------------------------------------------------------------------
read_txt <- function(path) {
  d <- read_csv(path, col_types = cols(.default = "c"), na = character(), show_col_types = FALSE)
  names(d) <- tolower(str_trim(names(d)))
  mutate(d, across(everything(), ~ str_to_upper(str_squish(.x))))
}
need <- function(path, how) {
  if (!file.exists(path)) stop("Missing ", path, ". Run: ", how, call. = FALSE)
  path
}
save_both <- function(table, plot, name, w = 9, h = 5.5) {
  write_csv(table, file.path("output", paste0(name, ".csv")))
  if (!is.null(plot)) ggsave(file.path("output", paste0(name, ".png")), plot, width = w, height = h, dpi = 300)
  message("  saved output/", name, ".csv", if (!is.null(plot)) " + .png")
}
theme_lab <- theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(color = "#52514e"),
        plot.caption = element_text(color = "#52514e", size = 8, hjust = 0),
        plot.title.position = "plot", plot.caption.position = "plot",
        panel.grid.minor = element_blank(), legend.position = "top",
        legend.justification = "left", plot.background = element_rect(fill = "white", color = NA))

# Registration status in plain words
status_group <- function(status_cd, reason) {
  case_when(
    status_cd == "A" & reason == "VERIFIED"           ~ "Active, verified",
    status_cd == "A"                                  ~ "Active, not yet verified",
    status_cd == "I" & str_detect(reason, "UNDELIVERABLE") ~ "Inactive, mail undeliverable",
    status_cd == "I"                                  ~ "Inactive, other",
    status_cd == "D" & str_detect(reason, "UNDELIVERABLE") ~ "Denied, mail undeliverable",
    status_cd == "D"                                  ~ "Denied, other",
    status_cd == "R"                                  ~ "Removed",
    TRUE                                              ~ "Other")
}
STATUS_LEVELS <- c("Active, verified", "Active, not yet verified", "Inactive, mail undeliverable",
                   "Inactive, other", "Denied, mail undeliverable", "Denied, other", "Removed",
                   "Other", "Not in Durham file")
STATUS_COLS <- setNames(c("#2a78d6", "#eda100", "#e34948", "#e87ba4", "#eb6834", "#6250d6",
                          "#52514e", "#8a8984", "#c3c2b7"), STATUS_LEVELS)

outcome_of <- function(pv_status) {
  factor(case_when(str_detect(pv_status, "PARTIAL")                   ~ "Partially counted",
                   str_detect(pv_status, "NOT COUNTED|DENIED|REJECT") ~ "Not counted",
                   str_detect(pv_status, "APPROVED|ACCEPTED|^COUNTED") ~ "Counted",
                   TRUE                                               ~ "Other / unknown"),
         levels = c("Counted", "Partially counted", "Not counted", "Other / unknown"))
}
OUTCOME_COLS <- c("Counted" = "#2a78d6", "Partially counted" = "#eda100",
                  "Not counted" = "#eb6834", "Other / unknown" = "#8a8984")

is_1801 <- function(x) str_detect(x, "^1801 FAYET+E?VILLE")

# Mailing address type. Blank mailing fields = mail goes to the residence.
mail_type <- function(res_street, mail1, mail2, mail_city, mail_state) {
  uses_res <- mail1 == ""
  m1 <- if_else(uses_res, res_street, mail1)
  m2 <- if_else(uses_res, "", mail2)
  room <- m2 != "" | str_detect(m1, "#|\\bAPT\\b|\\bRM\\b|ROOM|HALL|LANDING|TOWER|SUITE|UNIT|\\b\\d{3}[A-Z]?$")
  case_when(
    str_detect(paste(m1, m2), "P\\.?\\s?O\\.?\\s?BOX|^POB\\b|^BOX\\b") ~ "PO Box",
    is_1801(m1) & !room                                        ~ "Bare 1801 Fayetteville St",
    is_1801(m1) | (room & str_detect(m1, "HALL|LANDING|TOWER")) ~ "1801 Fayetteville + dorm/room",
    !uses_res & mail_state != "" & mail_state != "NC"          ~ "Home address, out of state",
    !uses_res & mail_city != "" & mail_city != "DURHAM"        ~ "Home address, elsewhere in NC",
    TRUE                                                       ~ "Other Durham address")
}
MAIL_LEVELS <- c("Bare 1801 Fayetteville St", "1801 Fayetteville + dorm/room", "PO Box",
                 "Other Durham address", "Home address, elsewhere in NC", "Home address, out of state")
MAIL_COLS <- setNames(c("#eb6834", "#2a78d6", "#eda100", "#8a8984", "#1baf7a", "#6250d6"), MAIL_LEVELS)

# ---- load data -------------------------------------------------------------------
message("Loading data ...")
prov_files <- list.files("data/processed", "^nccu_prov_\\d{4}\\.csv$", full.names = TRUE)
if (!length(prov_files)) need("data/processed/nccu_prov_2024.csv", "python nccu/load_nccu_all_years.py")
prov <- bind_rows(lapply(prov_files, function(f) read_txt(f) |>
                           mutate(year = as.integer(str_extract(basename(f), "\\d{4}"))))) |>
  filter(voted_pct_lbl %in% PRECINCTS) |>
  mutate(outcome = outcome_of(pv_status),
         no_record = str_detect(pv_voted_reason, "NO RECORD|REMOVED"),
         campus = is_1801(res_addr_street))

reg <- read_txt(need("data/processed/reg_current_nccu_related.csv", "python nccu/load_nccu_all_years.py")) |>
  mutate(status_now = status_group(status_cd, voter_status_reason_desc),
         birth_year = suppressWarnings(as.integer(birth_year)),
         reg_date = as.Date(registr_dt, "%m/%d/%Y"))
reg_by_num <- reg |> distinct(voter_reg_num, .keep_all = TRUE)

vhis <- read_txt(need("data/processed/vhis_nccu_generals.csv", "python nccu/load_nccu_all_years.py")) |>
  mutate(year = as.integer(str_sub(election_lbl, -4)))

snap24 <- if (file.exists("data/processed/snapshot_24_nccu.csv")) read_txt("data/processed/snapshot_24_nccu.csv") else NULL

abdel_denied <- if (file.exists("data/abdel/NCCU_Denied_Registrations_Unverifiable.xlsx"))
  read_excel("data/abdel/NCCU_Denied_Registrations_Unverifiable.xlsx", sheet = "Full list") else NULL
abdel_prov <- if (file.exists("data/abdel/NCCU_Provisional_Ballots_Registered.xlsx"))
  read_excel("data/abdel/NCCU_Provisional_Ballots_Registered.xlsx", sheet = "Full list") else NULL

# age at the election: 2024 snapshot age if present, else birth year in today's file
prov <- prov |>
  left_join(reg_by_num |> select(voter_reg_num, ncid, birth_year, status_now, reg_date,
                                 status_reason_now = voter_status_reason_desc),
            by = "voter_reg_num") |>
  mutate(age = year - birth_year, youth = age %in% YOUTH,
         election_date = as.Date(ELECTION_DATES[as.character(year)], "%m/%d/%Y"))
if (!is.null(snap24)) {
  prov <- prov |>
    left_join(snap24 |> transmute(voter_reg_num, age24 = as.integer(age)) |> distinct(voter_reg_num, .keep_all = TRUE),
              by = "voter_reg_num") |>
    mutate(age = if_else(year == 2024 & !is.na(age24), age24, age), youth = age %in% YOUTH) |>
    select(-age24)
}
message("  provisional ballots by year: ", paste(names(table(prov$year)), table(prov$year), sep = "=", collapse = ", "))

# =============================================================================
# PORTRAIT — provisionals cast and thrown vs. young people who voted successfully
# =============================================================================
message("\nPORTRAIT")
voters <- vhis |>
  distinct(year, voter_reg_num, voting_method) |>
  left_join(reg_by_num |> select(voter_reg_num, birth_year), by = "voter_reg_num") |>
  mutate(youth = (year - birth_year) %in% YOUTH) |>
  group_by(year) |>
  summarise(voted_all = n_distinct(voter_reg_num),
            voted_youth = n_distinct(voter_reg_num[youth]),
            voted_age_unknown = n_distinct(voter_reg_num[is.na(birth_year)]), .groups = "drop")

portrait <- prov |>
  group_by(year) |>
  summarise(prov_cast = n(),
            prov_not_counted = sum(outcome == "Not counted"),
            prov_partial = sum(outcome == "Partially counted"),
            prov_cast_youth = sum(youth),
            prov_not_counted_youth = sum(youth & outcome == "Not counted"),
            prov_age_unknown = sum(is.na(age)), .groups = "drop") |>
  full_join(voters, by = "year") |>
  arrange(year) |>
  mutate(thrown_per_1000_youth_voters = round(1000 * prov_not_counted_youth / voted_youth, 1))

pl <- portrait |>
  transmute(year = factor(year),
            `Young voters (18-25) whose ballots counted` = voted_youth,
            `Young voters (18-25) whose provisional ballots were not counted` = prov_not_counted_youth) |>
  pivot_longer(-year, names_to = "measure", values_to = "n") |>
  mutate(measure = fct_inorder(measure))
p <- ggplot(pl, aes(year, n)) +
  geom_col(width = 0.6, fill = "#2a78d6") +
  geom_text(aes(label = comma(n)), vjust = -0.4, size = 3.4) +
  facet_wrap(~ measure, scales = "free_y", ncol = 1) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15)), labels = comma) +
  labs(title = "NCCU precincts: young voters who voted vs. young voters whose provisional ballots were thrown out",
       subtitle = "Durham precincts 55-49 and 55-11, general elections. Panels use different scales.",
       x = NULL, y = NULL,
       caption = paste("Young voters = ages 18-25 at the election, from voter history; ages from today's",
                       "registration file (voters purged since are missing).\n", SOURCE)) +
  theme_lab + theme(strip.text = element_text(face = "bold", hjust = 0, size = 11),
                    panel.grid.major.x = element_blank())
save_both(portrait, p, "portrait_voters_vs_provisionals", h = 6.5)
print(portrait, width = Inf)

# =============================================================================
# Q1 — 2024 provisional voters today
# =============================================================================
message("\nQ1")
p24 <- prov |> filter(year == 2024)

# re-registration: any record for the same person (NCID) dated after election day
later_reg <- reg |>
  filter(ncid != "", reg_date > as.Date("2024-11-05")) |>
  group_by(ncid) |>
  summarise(reregistered = TRUE,
            rereg_status = paste(unique(status_group(status_cd, voter_status_reason_desc)), collapse = "; "),
            .groups = "drop")

q1 <- p24 |>
  left_join(later_reg, by = "ncid") |>
  mutate(status_now = factor(coalesce(status_now, "Not in Durham file"), levels = STATUS_LEVELS),
         reregistered = coalesce(reregistered, FALSE),
         on_abdel_denied_list = if (!is.null(abdel_denied)) ncid %in% str_to_upper(abdel_denied$NCID) else NA)

q1_table <- q1 |> count(status_now, outcome, name = "voters") |> arrange(status_now)
q1_head <- tibble(
  measure = c("2024 provisional voters (cast in 55-49/55-11)",
              "  still registered in Durham, active & verified",
              "  active but not yet verified",
              "  inactive", "  denied", "  removed", "  not in the Durham file at all",
              "  re-registered after Nov 5, 2024 (same NCID)",
              "    ...and that new registration is active & verified",
              "  on Abdel's denied-undeliverable list"),
  n = c(nrow(q1), sum(q1$status_now == "Active, verified"),
        sum(q1$status_now == "Active, not yet verified"),
        sum(str_starts(q1$status_now, "Inactive")), sum(str_starts(q1$status_now, "Denied")),
        sum(q1$status_now == "Removed"), sum(q1$status_now == "Not in Durham file"),
        sum(q1$reregistered), sum(q1$reregistered & str_detect(coalesce(q1$rereg_status, ""), "Active, verified")),
        if (is.null(abdel_denied)) NA else sum(q1$on_abdel_denied_list, na.rm = TRUE)))
print(q1_head, n = Inf)
write_csv(q1_head, "output/q1_headline.csv")

p <- ggplot(q1_table, aes(x = voters, y = fct_rev(status_now), fill = outcome)) +
  geom_col(width = 0.65, color = "white", linewidth = 0.4) +
  scale_fill_manual(values = OUTCOME_COLS, name = "2024 ballot:", drop = TRUE) +
  labs(title = "Where are NCCU's 2024 provisional voters now?",
       subtitle = sprintf("The %d people who cast a provisional ballot in 55-49 or 55-11, by their registration status today",
                          nrow(q1)),
       x = "Voters", y = NULL,
       caption = paste("'Not in Durham file' may mean they moved counties or were purged.\n", SOURCE)) +
  theme_lab + theme(panel.grid.major.y = element_blank())
save_both(q1_table, p, "q1_2024_provisional_voters_now")

# Q1b — pending verifications / denials at 1801 Fayetteville in today's file
q1b <- reg |>
  filter(is_1801(res_street_address)) |>
  mutate(registered = format(reg_date, "%Y")) |>
  count(status_now, name = "registrations") |>
  mutate(share = round(registrations / sum(registrations), 3))
save_both(q1b, NULL, "q1b_1801_fayetteville_status_now")
print(q1b)

if (!is.null(abdel_denied)) {
  q1c <- abdel_denied |>
    mutate(year_registered = format(as.Date(Registered), "%Y"),
           bare_1801 = str_detect(Address, "^1801 Fayetteville St$")) |>
    count(year_registered, `On campus`, bare_1801, `Re-registered?`, `New status`, name = "people")
  save_both(q1c, NULL, "q1c_abdel_denied_list_summary")
}

# =============================================================================
# Q2 — is the bare 1801 Fayetteville address the problem?
# Compare mailing addresses of VERIFIED vs. NOT VERIFIED / DENIED registrants
# who live at 1801 Fayetteville, in both precincts.
# =============================================================================
message("\nQ2")
q2_now <- reg |>
  filter(is_1801(res_street_address)) |>
  transmute(file = "Today's file", status = status_now,
            mail = mail_type(res_street_address, mail_addr1, mail_addr2, mail_city, mail_state))
q2_24 <- if (!is.null(snap24)) snap24 |>
  filter(house_num == "1801", str_detect(street_name, "FAYET")) |>
  mutate(res = str_squish(paste(house_num, street_name, street_type_cd, unit_designator, unit_num))) |>
  transmute(file = "Election Day 2024", status = status_group(status_cd, voter_status_reason_desc),
            mail = mail_type(res, mail_addr1, mail_addr2, mail_city, mail_state)) else NULL

q2 <- bind_rows(q2_24, q2_now) |>
  mutate(compare = case_when(status == "Active, verified" ~ "Verified",
                             str_detect(status, "not yet verified") ~ "Not yet verified",
                             str_detect(status, "undeliverable") ~ "Mail undeliverable (inactive or denied)",
                             TRUE ~ NA_character_)) |>
  filter(!is.na(compare)) |>
  count(file, compare, mail, name = "registrants") |>
  group_by(file, compare) |> mutate(total = sum(registrants), share = registrants / total) |> ungroup() |>
  mutate(file = factor(file, levels = c("Election Day 2024", "Today's file")),
         mail = factor(mail, levels = MAIL_LEVELS),
         row = paste0(compare, "  [", total, "]"))

p <- ggplot(q2, aes(x = share, y = fct_rev(row), fill = mail)) +
  geom_col(width = 0.65, color = "white", linewidth = 0.4, position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = ifelse(share >= 0.07, percent(share, 1), "")),
            position = position_stack(vjust = 0.5, reverse = TRUE), color = "white", fontface = "bold", size = 3.2) +
  facet_wrap(~ file, ncol = 1, scales = "free_y") +
  scale_fill_manual(values = MAIL_COLS, name = NULL, drop = FALSE) +
  scale_x_continuous(labels = percent, expand = expansion(mult = c(0, 0.01))) +
  guides(fill = guide_legend(nrow = 2)) +
  labs(title = "Do verified NCCU registrants give 'better' mailing addresses?",
       subtitle = "Registrants living at 1801 Fayetteville St, precincts 55-49 + 55-11 [number of people]",
       x = "Share of registrants", y = NULL,
       caption = paste("Blank mailing address = mail goes to the residence. If 'bare 1801' is just as common",
                       "among verified voters, the bare address alone is not the problem.\n", SOURCE)) +
  theme_lab + theme(strip.text = element_text(face = "bold", hjust = 0, size = 11),
                    panel.grid.major.y = element_blank())
save_both(q2 |> select(-row), p, "q2_mailing_address_verified_vs_not", w = 10.5, h = 6.5)

# =============================================================================
# Q3 — link between unverified/undeliverable registrations and provisionals
# For each election: of the provisional voters, how many had their registration
# created ON election day (by the provisional itself) and how many are now
# denied/inactive because mail came back undeliverable?
# =============================================================================
message("\nQ3")
q3 <- prov |>
  mutate(reg_created_election_day = !is.na(reg_date) & reg_date == election_date,
         undeliverable_now = str_detect(coalesce(status_reason_now, ""), "UNDELIVERABLE"),
         denied_now = str_starts(coalesce(status_now, ""), "Denied")) |>
  group_by(year) |>
  summarise(provisional_ballots = n(),
            `no record / previously removed` = sum(no_record),
            `registration created on election day` = sum(reg_created_election_day),
            `now denied or inactive: mail undeliverable` = sum(undeliverable_now),
            `undeliverable AND ballot not counted` = sum(undeliverable_now & outcome == "Not counted"),
            `lived at 1801 Fayetteville` = sum(campus), .groups = "drop")
if (!is.null(abdel_denied))
  q3 <- q3 |> left_join(prov |> group_by(year) |>
                          summarise(`on Abdel's denied list` = sum(ncid %in% str_to_upper(abdel_denied$NCID))),
                        by = "year")
print(q3, width = Inf)

q3l <- q3 |>
  select(year, provisional_ballots, `no record / previously removed`,
         `now denied or inactive: mail undeliverable`, `undeliverable AND ballot not counted`) |>
  pivot_longer(-year, names_to = "step", values_to = "n") |>
  mutate(step = fct_inorder(str_replace(step, "provisional_ballots", "provisional ballots cast")))
p <- ggplot(q3l, aes(x = factor(year), y = n, fill = step)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  geom_text(aes(label = n), position = position_dodge(width = 0.8), vjust = -0.3, size = 3) +
  scale_fill_manual(values = c("#8a8984", "#eda100", "#e34948", "#eb6834"), name = NULL) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  guides(fill = guide_legend(nrow = 2)) +
  labs(title = "From provisional ballot to undeliverable registration, NCCU precincts",
       subtitle = "Provisional ballots cast in 55-49 + 55-11 and what happened to those voters' registrations",
       x = NULL, y = "Voters",
       caption = paste("Registration status is today's, so older elections undercount (purged records drop out).\n", SOURCE)) +
  theme_lab + theme(panel.grid.major.x = element_blank())
save_both(q3, p, "q3_unverified_provisional_link", w = 10, h = 6)


