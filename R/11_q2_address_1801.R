# =============================================================================
# Q2 — Is "bare 1801 Fayetteville St" the problem?
# NCCU has no PO boxes; students must list their dorm to get mail. If bare
# 1801 Fayetteville addresses drive unverifiability, VERIFIED registrants in
# 55-11/55-49 should have "better" mailing addresses (dorm + room, or a home
# address elsewhere) than UNVERIFIED / UNDELIVERABLE registrants.
# If bare 1801 shows up heavily in both groups, the address alone isn't the story.
# =============================================================================
source("R/02_functions.R")

years_avail <- ELECTIONS$year[vapply(ELECTIONS$year, function(y)
  !is.na(find_file(sprintf("snapshot_%d_nccu.csv", y), if (y == 2024) "snapshot_24_nccu.csv" else character())),
  logical(1))]

reg_all <- bind_rows(
  lapply(years_avail, function(y) load_snapshot(y) |> mutate(file = paste0("Election day ", y))),
  load_current_reg() |> mutate(file = "Current file (2026)")
) |>
  filter(on_campus) |>
  mutate(
    # Keep statuses separate: lumping "pending" (mostly brand-new registrants)
    # with "undeliverable" hides opposite patterns.
    verification = factor(str_remove(status_group, "^(Active|Inactive) - "),
                          levels = c("verified", "pending verification/confirmation", "unverified",
                                     "mail returned undeliverable", "confirmation not returned",
                                     "DL/SSN update needed", "Removed / denied", "Other")),
    status_label = factor(status_group),
    reg_year = as.integer(str_sub(registr_dt, -4)),
    file = factor(file, levels = c(paste0("Election day ", years_avail), "Current file (2026)"))
  )

# ---- Tables -------------------------------------------------------------------------
q2_counts <- reg_all |>
  count(file, verification, mail_class, name = "registrants", .drop = FALSE) |>
  group_by(file, verification) |>
  mutate(share = registrants / sum(registrants)) |>
  ungroup() |>
  filter(!is.na(share))
readr::write_csv(q2_counts, file.path(DIR_TABLES, "q2_mailing_address_by_status.csv"))

q2_youth <- reg_all |>
  filter(youth) |>
  count(file, verification, mail_class, name = "registrants_18_25") |>
  group_by(file, verification) |>
  mutate(share = registrants_18_25 / sum(registrants_18_25)) |>
  ungroup()
readr::write_csv(q2_youth, file.path(DIR_TABLES, "q2_mailing_address_by_status_youth.csv"))

# Headline: share of each group with a bare 1801 address
q2_headline <- reg_all |>
  group_by(file, verification) |>
  summarise(registrants = n(),
            bare_1801 = sum(mail_class == "Bare 1801 Fayetteville St"),
            share_bare_1801 = bare_1801 / registrants,
            share_home_address = mean(str_detect(mail_class, "home")),
            share_dorm_room = mean(mail_class == "1801 Fayetteville + dorm/room"),
            po_box = sum(mail_class == "PO Box"),
            .groups = "drop")
readr::write_csv(q2_headline, file.path(DIR_TABLES, "q2_headline.csv"))
print(q2_headline, n = Inf)

# Registration timing matters: dorm+room addresses are common among brand-new
# registrants who are still "pending". Compare like with like.
q2_by_cohort <- reg_all |>
  mutate(registered = if_else(reg_year >= as.integer(str_extract(as.character(file), "\\d{4}")),
                              "Registered in file year", "Registered earlier")) |>
  count(file, registered, verification, mail_class, name = "registrants")
readr::write_csv(q2_by_cohort, file.path(DIR_TABLES, "q2_mailing_address_by_status_and_reg_timing.csv"))

# Spot-check sample for hand review (are the address categories right?)
set.seed(17)
reg_all |> group_by(mail_class) |> slice_sample(n = 5) |> ungroup() |>
  select(file, mail_class, status_group, res_street) |>
  readr::write_csv("data/derived/q2_address_classification_spotcheck.csv")

# ---- Figure: address type by verification status ------------------------------------
mail_cols <- c("Bare 1801 Fayetteville St"      = PAL[["orange"]],
               "1801 Fayetteville + dorm/room"  = PAL[["blue"]],
               "PO Box"                          = PAL[["yellow"]],
               "Other Durham street address"     = PAL[["gray"]],
               "Elsewhere in NC (home) address"  = PAL[["aqua"]],
               "Out-of-state (home) address"     = PAL[["violet"]])

fig_q2 <- q2_counts |>
  filter(!verification %in% c("Other", "Removed / denied")) |>
  mutate(verification = fct_rev(fct_drop(verification))) |>
  group_by(file, verification) |>
  mutate(row_lab = paste0(verification, "  [", scales::comma(sum(registrants)), "]")) |>
  ungroup() |>
  mutate(row_lab = fct_reorder(row_lab, as.integer(verification), .desc = TRUE)) |>
  ggplot(aes(x = share, y = row_lab, fill = mail_class)) +
  geom_col(width = 0.7, color = "#fcfcfb", linewidth = 0.6, position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = ifelse(share >= 0.07, scales::percent(share, 1), "")),
            position = position_stack(vjust = 0.5, reverse = TRUE),
            color = "white", fontface = "bold", size = 3.4) +
  facet_wrap(~ file, ncol = 1, scales = "free_y") +
  scale_fill_manual(values = mail_cols, name = NULL, drop = FALSE) +
  scale_x_continuous(labels = scales::percent, expand = expansion(mult = c(0, 0.01))) +
  guides(fill = guide_legend(nrow = 2)) +
  labs(title = "What mailing address do NCCU-dorm registrants give?",
       subtitle = "Registrants whose residence is 1801 Fayetteville St, NCCU precincts, by registration status (number of registrants in brackets)",
       x = "Share of registrants", y = NULL,
       caption = str_wrap(paste0("Blank mailing fields mean mail goes to the residential address. ", SOURCE_NOTE), 160)) +
  theme_lab() +
  theme(strip.text = element_text(face = "bold", hjust = 0),
        panel.grid.major.y = element_blank())
save_fig(fig_q2, "q2_mailing_address_by_status", width = 11, height = 2.5 + 2.6 * nlevels(reg_all$file))
