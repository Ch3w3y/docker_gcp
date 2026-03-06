#!/usr/bin/env Rscript
# src/transform.R
#
# Orchestration script: transform step.
# Reads the raw isolate data from /tmp, applies cleaning and aggregation,
# and writes the monthly resistance rates to /tmp for the load step.

source("/workspace/config.R")
source("/workspace/R/utils.R")
source("/workspace/R/extract.R")
source("/workspace/R/transform.R")

log_message("=== TRANSFORM STEP ===")

# Read raw data from the extract step
isolates_raw <- readRDS("/tmp/amr_isolates_raw.rds")
log_message("Read ", nrow(isolates_raw), " raw rows from extract step")

# Step 1: Clean
log_message("Cleaning isolate records...")
isolates_clean <- clean_isolates(isolates_raw)
log_message("Retained ", nrow(isolates_clean), " records after cleaning")

# Step 2: Calculate monthly resistance rates
log_message("Calculating monthly resistance rates...")
monthly_rates <- calculate_resistance_rates(isolates_clean, min_isolates = 10)
log_message("Produced ", nrow(monthly_rates), " organism-country-month rate estimates")

low_count_n <- sum(monthly_rates$low_count)
if (low_count_n > 0) {
  log_message("Warning: ", low_count_n, " groups flagged as low-count (< 10 isolates)")
}

# Step 3: Flag high resistance
log_message("Flagging threshold breaches (>= 50% resistance)...")
monthly_rates <- flag_threshold_breaches(monthly_rates, threshold = 50)
breach_n <- sum(monthly_rates$breach)
log_message("Found ", breach_n, " organism-country-month combinations above threshold")

# Step 4: Produce wide matrix for dashboard
log_message("Pivoting to wide format for dashboard output...")
monthly_matrix <- pivot_to_wide(monthly_rates)
log_message("Wide matrix: ", nrow(monthly_matrix), " rows x ", ncol(monthly_matrix), " columns")

# Write results for the load step
saveRDS(monthly_rates,  "/tmp/amr_monthly_rates.rds")
saveRDS(monthly_matrix, "/tmp/amr_monthly_matrix.rds")

log_message("=== TRANSFORM COMPLETE ===")
