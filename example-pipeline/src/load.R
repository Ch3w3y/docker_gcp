#!/usr/bin/env Rscript
# src/load.R
#
# Orchestration script: load step.
# Reads the transformed data from /tmp and writes it to BigQuery.

source("/workspace/config.R")
source("/workspace/R/utils.R")
source("/workspace/R/extract.R")
source("/workspace/R/transform.R")
source("/workspace/R/load.R")

log_message("=== LOAD STEP ===")

# Read transformed data from the transform step
monthly_rates  <- readRDS("/tmp/amr_monthly_rates.rds")
monthly_matrix <- readRDS("/tmp/amr_monthly_matrix.rds")

# Write long-format monthly rates (primary output)
write_amr_summary(
  df      = monthly_rates,
  project = GCP_PROJECT_ID,
  dataset = BQ_DATASET,
  table   = BQ_OUTPUT_TABLE
)

# Write wide-format matrix (dashboard input)
write_amr_matrix(
  df      = monthly_matrix,
  project = GCP_PROJECT_ID,
  dataset = BQ_DATASET,
  table   = paste0(BQ_OUTPUT_TABLE, "_matrix")
)

log_message("=== LOAD COMPLETE ===")
