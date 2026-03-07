#!/usr/bin/env Rscript
# demo/generate_amr_outputs.R
#
# Generates publication-ready ggplot2 outputs from synthetic AMR surveillance
# data. No BigQuery connection required — uses the test fixtures from the
# example pipeline.
#
# Outputs saved to demo/outputs/:
#   - figure_01_resistance_trends.pdf / .png
#   - figure_02_country_heatmap.pdf / .png
#   - figure_03_breach_overview.pdf / .png
#   - figure_04_organism_comparison.pdf / .png
#
# Run locally:
#   Rscript demo/generate_amr_outputs.R
#
# Run inside Docker:
#   docker compose -f example-pipeline/docker-compose.yml run --rm pipeline \
#     Rscript /workspace/../demo/generate_amr_outputs.R

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(scales)
  library(glue)
})

# ── Source example pipeline functions ─────────────────────────────────────────

# Adjust paths based on whether we're running from repo root or inside container
repo_root <- if (file.exists("example-pipeline/R/extract.R")) {
  "."
} else if (file.exists("/workspace/../example-pipeline/R/extract.R")) {
  "/workspace/.."
} else {
  stop("Cannot locate example-pipeline/. Run from the repository root.")
}

source(file.path(repo_root, "example-pipeline/R/extract.R"))
source(file.path(repo_root, "example-pipeline/R/transform.R"))

# ── Generate synthetic data ────────────────────────────────────────────────────

cat("Generating synthetic AMR surveillance data...\n")

set.seed(42)

# Build a realistic synthetic dataset directly (mirrors make_test_isolates from setup.R)
generate_demo_data <- function(n_per_group = 40, months = 12,
                               start_date = as.Date("2024-01-01")) {
  expand.grid(
    organism_code = names(AMR_ORGANISMS),
    country_code  = names(AMR_COUNTRIES),
    month_offset  = 0:(months - 1)
  ) |>
    as_tibble() |>
    mutate(
      collection_date = start_date + months(month_offset),
      year_month      = format(collection_date, "%Y-%m"),
      organism        = AMR_ORGANISMS[organism_code],
      country         = AMR_COUNTRIES[country_code]
    ) |>
    # Different baseline resistance rates per organism to make it interesting
    mutate(
      base_resistance = case_when(
        organism_code == "ECOLI"  ~ 0.28,
        organism_code == "KPNEU" ~ 0.42,
        organism_code == "SAUR"  ~ 0.33,
        organism_code == "PAER"  ~ 0.52,
        organism_code == "ABAUM" ~ 0.65
      ),
      # Country modifiers
      country_modifier = case_when(
        country_code == "GB" ~ -0.05,
        country_code == "DE" ~ -0.08,
        country_code == "FR" ~  0.03,
        country_code == "IT" ~  0.07,
        country_code == "ES" ~  0.05
      ),
      # Slight upward trend over time
      trend = month_offset * 0.004,
      # Final resistance fraction (capped 0–0.95)
      resistance_frac = pmin(0.95, pmax(0.02,
        base_resistance + country_modifier + trend +
        rnorm(n(), sd = 0.05)
      ))
    ) |>
    # Expand to individual isolate records
    group_by(organism_code, country_code, year_month) |>
    reframe(
      collection_date = first(collection_date),
      organism        = first(organism),
      country         = first(country),
      isolate_id      = paste0(organism_code, "_", country_code, "_",
                               format(collection_date, "%Y%m"), "_", seq_len(n_per_group)),
      is_resistant    = rbinom(n_per_group, 1, unique(resistance_frac)) == 1
    )
}

raw <- generate_demo_data(n_per_group = 45, months = 12)
clean <- clean_isolates(raw)
rates <- calculate_resistance_rates(clean, min_isolates = 10)
rates_flagged <- flag_threshold_breaches(rates, threshold = 50)

cat(glue("  {nrow(raw)} isolate records across {length(unique(raw$year_month))} months\n"))
cat(glue("  {nrow(rates)} organism × country × month combinations\n"))
cat(glue("  {sum(rates_flagged$breach, na.rm = TRUE)} threshold breaches\n\n"))

# ── Consistent theme ──────────────────────────────────────────────────────────

# Okabe-Ito color-blind friendly palette
okabe_ito_palette <- c(
  "sky_blue"       = "#56B4E9",
  "orange"         = "#E69F00",
  "bluish_green"   = "#009E73",
  "blue"           = "#0072B2",
  "reddish_purple" = "#CC79A7",
  "vermillion"     = "#D55E00",
  "slate_900"      = "#0f172a",
  "slate_600"      = "#475569",
  "slate_100"      = "#f1f5f9"
)

modern_theme <- theme_minimal(base_size = 11) +
  theme(
    plot.title       = element_text(face = "bold", size = 13, colour = okabe_ito_palette["slate_900"], margin = margin(b = 4)),
    plot.subtitle    = element_text(colour = okabe_ito_palette["slate_600"], size = 10, margin = margin(b = 10)),
    plot.caption     = element_text(colour = okabe_ito_palette["slate_600"], size = 8, margin = margin(t = 8)),
    plot.background  = element_rect(fill = okabe_ito_palette["slate_100"], colour = NA),
    panel.background = element_rect(fill = okabe_ito_palette["slate_100"], colour = NA),
    plot.margin      = margin(12, 12, 8, 12),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "white", linewidth = 0.5),
    strip.text       = element_text(face = "bold", size = 9, colour = okabe_ito_palette["slate_900"]),
    legend.position  = "bottom",
    legend.title     = element_text(face = "bold", size = 9),
    legend.text      = element_text(size = 8),
    axis.title       = element_text(size = 9, colour = okabe_ito_palette["slate_900"]),
    axis.text        = element_text(size = 8, colour = okabe_ito_palette["slate_600"])
  )

theme_set(modern_theme)

organism_colours <- c(
  "ECOLI"  = okabe_ito_palette["sky_blue"],
  "KPNEU"  = okabe_ito_palette["orange"],
  "SAUR"   = okabe_ito_palette["bluish_green"],
  "PAER"   = okabe_ito_palette["blue"],
  "ABAUM"  = okabe_ito_palette["reddish_purple"]
)

organism_labels <- c(
  "ECOLI"  = "E. coli",
  "KPNEU"  = "K. pneumoniae",
  "SAUR"   = "S. aureus",
  "PAER"   = "P. aeruginosa",
  "ABAUM"  = "A. baumannii"
)

# ── Output directory ──────────────────────────────────────────────────────────

out_dir <- file.path(dirname(sys.frame(1)$ofile %||% "demo"), "outputs")
if (!file.exists(out_dir)) {
  out_dir <- "demo/outputs"
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

save_plot <- function(p, name, w = 24, h = 14) {
  pdf_path <- file.path(out_dir, paste0(name, ".pdf"))
  png_path <- file.path(out_dir, paste0(name, ".png"))
  ggsave(pdf_path, p, width = w, height = h, units = "cm")
  ggsave(png_path, p, width = w, height = h, units = "cm", dpi = 150)
  cat(glue("  Saved {name}.pdf and .png\n"))
}

# ── Figure 1: Resistance trends by organism (faceted by country) ──────────────

cat("Generating Figure 1: Resistance trends...\n")

p1 <- rates_flagged |>
  filter(!low_count) |>
  mutate(
    organism_label = organism_labels[organism_code],
    organism_label = factor(organism_label, levels = organism_labels)
  ) |>
  ggplot(aes(
    x      = year_month,
    y      = pct_resistant,
    colour = organism_code,
    group  = organism_code
  )) +
  geom_hline(yintercept = 50, linetype = "dashed", colour = okabe_ito_palette["vermillion"],
             alpha = 0.5, linewidth = 0.5) +
  geom_line(linewidth = 0.75) +
  geom_point(aes(shape = breach), size = 2, alpha = 0.8) +
  scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17),
                     labels = c("Below threshold", "Breach (≥50%)"),
                     name   = NULL) +
  facet_wrap(~country_code, ncol = 5, labeller = labeller(
    country_code = c(GB = "United Kingdom", DE = "Germany",
                     FR = "France", IT = "Italy", ES = "Spain")
  )) +
  scale_colour_manual(values = organism_colours, labels = organism_labels,
                      name = "Organism") +
  scale_y_continuous(
    limits = c(0, 100),
    labels = function(x) paste0(x, "%"),
    breaks = c(0, 25, 50, 75, 100)
  ) +
  scale_x_discrete(guide = guide_axis(angle = 45)) +
  guides(colour = guide_legend(nrow = 1), shape = guide_legend(nrow = 1)) +
  labs(
    title    = "Antimicrobial Resistance Surveillance — Monthly Trends",
    subtitle = "12-month surveillance period | Five European countries | Five priority organisms",
    x        = NULL,
    y        = "% isolates resistant",
    caption  = paste0(
      "Red dashed line: 50% alert threshold.  ",
      "Triangles: threshold breaches.  ",
      "Groups with <10 isolates excluded.  ",
      "Data: synthetic, for demonstration only."
    )
  )

save_plot(p1, "figure_01_resistance_trends", w = 28, h = 16)

# ── Figure 2: Country × Organism heatmap ─────────────────────────────────────

cat("Generating Figure 2: Country heatmap...\n")

heatmap_data <- rates_flagged |>
  filter(!low_count) |>
  group_by(organism_code, country_code) |>
  summarise(
    mean_pct   = mean(pct_resistant, na.rm = TRUE),
    n_breaches = sum(breach, na.rm = TRUE),
    n_months   = n(),
    .groups    = "drop"
  ) |>
  mutate(
    organism_label = organism_labels[organism_code],
    country_label  = c(GB = "United Kingdom", DE = "Germany",
                       FR = "France", IT = "Italy", ES = "Spain")[country_code],
    organism_label = factor(organism_label, levels = rev(organism_labels)),
    country_label  = factor(country_label,
                            levels = c("United Kingdom", "Germany", "France", "Italy", "Spain"))
  )

p2 <- heatmap_data |>
  ggplot(aes(x = country_label, y = organism_label, fill = mean_pct)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.0f%%", mean_pct)),
            size = 3.8, fontface = "bold",
            colour = ifelse(heatmap_data$mean_pct > 60, "white", "grey20")) +
  scale_fill_gradient2(
    low      = okabe_ito_palette["blue"],
    mid      = "white",
    high     = okabe_ito_palette["vermillion"],
    midpoint = 40,
    limits   = c(0, 100),
    name     = "Mean % resistant",
    labels   = function(x) paste0(x, "%")
  ) +
  scale_x_discrete(position = "top") +
  labs(
    title    = "Mean Resistance Rate by Organism and Country",
    subtitle = "Averaged over 12-month surveillance period",
    x        = NULL,
    y        = NULL,
    caption  = "Data: synthetic, for demonstration only."
  ) +
  theme(
    axis.text.x   = element_text(face = "bold", size = 10),
    axis.text.y   = element_text(face = "italic", size = 10),
    panel.grid    = element_blank(),
    legend.position = "right"
  )

save_plot(p2, "figure_02_country_heatmap", w = 22, h = 14)

# ── Figure 3: Threshold breach summary ───────────────────────────────────────

cat("Generating Figure 3: Threshold breach overview...\n")

breach_summary <- rates_flagged |>
  filter(!low_count) |>
  group_by(organism_code, country_code) |>
  summarise(
    n_months  = n(),
    n_breaches = sum(breach, na.rm = TRUE),
    pct_months_in_breach = 100 * n_breaches / n_months,
    .groups = "drop"
  ) |>
  mutate(
    organism_label = organism_labels[organism_code],
    organism_label = factor(organism_label, levels = organism_labels),
    country_label  = c(GB = "United Kingdom", DE = "Germany",
                       FR = "France", IT = "Italy", ES = "Spain")[country_code]
  )

p3 <- breach_summary |>
  ggplot(aes(
    x    = country_label,
    y    = pct_months_in_breach,
    fill = organism_code
  )) +
  geom_col(position = "dodge", width = 0.75, colour = "white", linewidth = 0.3) +
  geom_hline(yintercept = 50, linetype = "dashed", colour = "grey40", alpha = 0.6) +
  scale_fill_manual(values = organism_colours, labels = organism_labels, name = "Organism") +
  scale_y_continuous(
    limits = c(0, 100),
    labels = function(x) paste0(x, "%"),
    breaks = c(0, 25, 50, 75, 100)
  ) +
  labs(
    title    = "Months in Alert: Proportion of Surveillance Period Above Threshold",
    subtitle = "Percentage of months where resistance rate exceeded 50% alert threshold",
    x        = NULL,
    y        = "% months in breach",
    caption  = "Dashed line: 50% of months in breach.  Data: synthetic, for demonstration only."
  ) +
  theme(axis.text.x = element_text(face = "bold"))

save_plot(p3, "figure_03_breach_overview", w = 26, h = 14)

# ── Figure 4: Resistance distribution ridge / violin ─────────────────────────

cat("Generating Figure 4: Organism comparison...\n")

p4 <- rates_flagged |>
  filter(!low_count) |>
  mutate(
    organism_label = organism_labels[organism_code],
    organism_label = factor(organism_label, levels = rev(organism_labels))
  ) |>
  ggplot(aes(x = pct_resistant, y = organism_label, fill = organism_code)) +
  geom_violin(trim = TRUE, alpha = 0.7, colour = "white") +
  geom_boxplot(width = 0.15, fill = "white", colour = "grey30",
               outlier.size = 1, alpha = 0.9) +
  geom_vline(xintercept = 50, linetype = "dashed", colour = okabe_ito_palette["vermillion"],
             alpha = 0.6, linewidth = 0.6) +
  scale_fill_manual(values = organism_colours, guide = "none") +
  scale_x_continuous(
    limits = c(0, 100),
    labels = function(x) paste0(x, "%"),
    breaks = c(0, 25, 50, 75, 100)
  ) +
  facet_wrap(~country_code, ncol = 5, labeller = labeller(
    country_code = c(GB = "United Kingdom", DE = "Germany",
                     FR = "France", IT = "Italy", ES = "Spain")
  )) +
  labs(
    title    = "Distribution of Monthly Resistance Rates by Organism",
    subtitle = "Violin plots show the distribution across all 12 months | Box shows IQR and median",
    x        = "% isolates resistant",
    y        = NULL,
    caption  = "Red dashed line: 50% alert threshold.  Data: synthetic, for demonstration only."
  ) +
  theme(axis.text.y = element_text(face = "italic"))

save_plot(p4, "figure_04_organism_distribution", w = 28, h = 16)

# ── Summary ───────────────────────────────────────────────────────────────────

cat("\nAll outputs written to: ", out_dir, "\n")
cat("Files:\n")
for (f in list.files(out_dir, full.names = FALSE)) {
  cat("  ", f, "\n")
}

cat("\nTo upload to GCS:\n")
cat("  Rscript demo/upload_to_gcs.R\n\n")
