# Share of provisional ballots thrown out, by age group, NCCU precincts 55-49 + 55-11
# Uses the team's NCCU_Summary_Labeled.csv.  Run: source("thrown_rate_chart.R")
library(dplyr); library(readr); library(ggplot2)
d <- read_csv("NCCU_Summary_Labeled.csv", show_col_types = FALSE)
names(d) <- trimws(names(d))
d <- d |>
  filter(`Age Group` %in% c("under25", "25plus")) |>
  mutate(group = factor(ifelse(`Age Group` == "under25", "Under 25", "25 and older"),
                        levels = c("Under 25", "25 and older")),
         pct = `Provisionals Thrown` / `Total Provisionals Cast`,
         label = paste0(round(100 * pct), "%\n(", `Provisionals Thrown`, " of ", `Total Provisionals Cast`, ")"))
p <- ggplot(d, aes(factor(Year), pct, fill = group)) +
  geom_col(position = position_dodge(0.8), width = 0.75) +
  geom_text(aes(label = label), position = position_dodge(0.8), vjust = -0.25, size = 3, lineheight = 0.9) +
  scale_fill_manual(values = c("Under 25" = "#eb6834", "25 and older" = "#8a8984"), name = NULL) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1.15), breaks = seq(0, 1, .25),
                     expand = expansion(mult = c(0, 0))) +
  labs(title = "Young voters' provisional ballots at NCCU are thrown out far more often",
       subtitle = "Share of provisional ballots not counted, Durham precincts 55-49 and 55-11, general elections",
       x = NULL, y = "Provisional ballots thrown out",
       caption = paste("Excludes voters whose age is unknown (no registration record).",
                       "Source: NC State Board of Elections. Student Voting Rights Lab, Duke.")) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), plot.title.position = "plot",
        plot.caption.position = "plot", plot.caption = element_text(hjust = 0, color = "#52514e", size = 8),
        legend.position = "top", legend.justification = "left",
        panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = "white", color = NA))
ggsave("provisionals_thrown_by_age.png", p, width = 9, height = 5.5, dpi = 300)
