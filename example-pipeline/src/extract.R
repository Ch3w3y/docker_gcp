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

# ---- Pseudonymisation Step ----
# In a real RAP, we would pseudonymise the patient identifier (e.g. NHS Number)
# as the very first step. Here we create a dummy 'patient_id' and hash it.
log_message("Pseudonymising patient identifiers...")

# 1. Retrieve the 'SALT' from an environment variable (set via GCP Secret Manager)
salt <- Sys.getenv("PIPELINE_SALT")
if (nchar(salt) == 0) {
  log_message("Warning: PIPELINE_SALT not set. using 'default_salt' for demo.")
  salt <- "default_salt"
}

# 2. Add a dummy identifiable 'patient_id' and hash it
# In reality, 'patient_id' would already be in isolates_raw from BigQuery
isolates_raw$patient_id <- paste0("PATIENT-", sample(1000:9999, nrow(isolates_raw), replace = TRUE))

# 3. Hash the ID with the salt
# We use the digest package (ensure it is in the Docker image)
isolates_raw$pseudo_id <- sapply(isolates_raw$patient_id, function(id) {
  digest::digest(paste0(id, salt), algo = "sha256", serialize = FALSE)
})

# 4. Drop the original identifiable column immediately
isolates_raw$patient_id <- NULL
log_message("Pseudonymisation complete. Identifiable 'patient_id' dropped.")

# Validate the extract
validate_extract(isolates_raw)

# Write to a temporary file so the load step can read it
# Using RDS format to preserve date types across steps
output_path <- "/tmp/amr_isolates_raw.rds"
saveRDS(isolates_raw, output_path)
log_message("Raw data written to ", output_path)
log_message("=== EXTRACT COMPLETE: ", nrow(isolates_raw), " rows ===")
