# =============================================================================
# 00_setup.R — packages, paths, and constants shared by every NCCU script
# =============================================================================
# Run from the repo root (open voting-rights-lab.Rproj or setwd() to the repo).

pkgs <- c("dplyr", "tidyr", "readr", "stringr", "ggplot2", "scales",
          "forcats", "data.table")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing)
invisible(lapply(pkgs, library, character.only = TRUE))

# ---- Paths ------------------------------------------------------------------
DIR_RAW       <- "data/raw"          # big NCSBE downloads (git-ignored)
DIR_PROCESSED <- "data/processed"    # NCCU-precinct extracts
DIR_UNVERIF   <- "data/raw/unverified"  # drop Carter's unverifiable-address files here
DIR_TABLES    <- "output/tables"
DIR_FIGS      <- "output/figures"
for (d in c(DIR_RAW, DIR_PROCESSED, DIR_UNVERIF, DIR_TABLES, DIR_FIGS, "data/derived")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ---- Study definition -------------------------------------------------------
DURHAM_COUNTY_ID <- "32"
NCCU_PRECINCTS   <- c("55-11", "55-49")   # together these cover every NCCU dorm
YOUTH_AGES       <- 18:25
NCCU_STREET      <- "1801 FAYETTEVILLE"

# General elections in scope. Dates drive the NCSBE file names.
# VERIFY each URL on https://dl.ncsbe.gov/ before a big download: NCSBE has
# changed folder names/formats over time (older provisional files may be .zip).
ELECTIONS <- tibble::tribble(
  ~year, ~date,       ~type,
  2016,  "20161108",  "Presidential",
  2018,  "20181106",  "Midterm",
  2020,  "20201103",  "Presidential",
  2022,  "20221108",  "Midterm",
  2024,  "20241105",  "Presidential"
) |>
  mutate(
    date_dash     = paste(substr(date, 1, 4), substr(date, 5, 6), substr(date, 7, 8), sep = "_"),
    prov_url      = sprintf("https://s3.amazonaws.com/dl.ncsbe.gov/ENRS/%s/provisional_%s.txt",
                            date_dash, date),
    snapshot_url  = sprintf("https://s3.amazonaws.com/dl.ncsbe.gov/data/Snapshots/VR_Snapshot_%s.zip",
                            date)
  )

# Current Durham County files (refreshed weekly by NCSBE)
CURRENT_REG_URL  <- "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvoter32.zip"
CURRENT_HIST_URL <- "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvhis32.zip"
# Statewide file — only needed to see if voters re-registered in ANOTHER county
STATEWIDE_REG_URL <- "https://s3.amazonaws.com/dl.ncsbe.gov/data/ncvoter_Statewide.zip"

# ---- Plot theme + palette (colorblind-validated categorical order) ----------
PAL <- c(blue = "#2a78d6", orange = "#eb6834", aqua = "#1baf7a",
         yellow = "#eda100", magenta = "#e87ba4", green = "#008300",
         violet = "#6250d6", red = "#e34948", gray = "#8a8984")

theme_lab <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title         = element_text(face = "bold", size = base_size + 3),
      plot.subtitle      = element_text(color = "#52514e", margin = margin(b = 10)),
      plot.caption       = element_text(color = "#52514e", size = base_size - 3, hjust = 0),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(color = "#e6e5e0", linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      axis.text          = element_text(color = "#52514e"),
      legend.position    = "top",
      legend.justification = "left",
      plot.background    = element_rect(fill = "#fcfcfb", color = NA)
    )
}

save_fig <- function(plot, name, width = 9, height = 5.5) {
  ggsave(file.path(DIR_FIGS, paste0(name, ".png")), plot,
         width = width, height = height, dpi = 300, bg = "#fcfcfb")
  invisible(plot)
}

SOURCE_NOTE <- "Source: NC State Board of Elections (provisional, snapshot, and voter registration files). Student Voting Rights Lab, Duke."
