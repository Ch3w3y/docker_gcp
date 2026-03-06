#!/usr/bin/env Rscript
# src/extract.R
#
# Orchestration script: extract step.
# Sources the R package functions, fetches AMR isolate data from BigQuery,
# validates it, and writes it to a temporary file for the next step.
#
# This script is intentionally thin — all business logic lives in R/.

source("/workspace/config.R")
source("/workspace/R/utils.R")
source("/workspace/R/extract.R")
source("/workspace/R/transform.R")
source("/workspace/R/load.R")

log_message("=== EXTRACT STEP ===")

# Authenticate to GCP (uses Application Default Credentials automatically)
bigrquery::bq_auth()

# Fetch the last 12 months of isolate records
isolates_raw <- fetch_isolates(
  project = GCP_PROJECT_ID,
  dataset = BQ_DATASET,
  table   = BQ_SOURCE_TABLE,
  months  = 12
)

# Validate the extract
validate_extract(isolates_raw)

# Write to a temporary file so the load step can read it
# Using RDS format to preserve date types across steps
output_path <- "/tmp/amr_isolates_raw.rds"
saveRDS(isolates_raw, output_path)
log_message("Raw data written to ", output_path)
log_message("=== EXTRACT COMPLETE: ", nrow(isolates_raw), " rows ===")
