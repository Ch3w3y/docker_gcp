# config.R
#
# Centralised configuration and environment variable validation.
# Source this file at the top of each orchestration script.
#
# Pattern: validate everything up front. The pipeline should fail immediately
# with a clear message if configuration is missing, rather than silently
# failing halfway through a multi-hour run.

# ---- Required variables ----
# Each entry must be set in .env (locally) or Secret Manager (Cloud Run).

required_env_vars <- c(
  "GCP_PROJECT_ID",   # GCP project ID
  "BQ_DATASET",       # BigQuery dataset containing referrals data
  "GCS_DATA_BUCKET"   # GCS bucket for output files
)

missing_vars <- required_env_vars[!nzchar(Sys.getenv(required_env_vars))]

if (length(missing_vars) > 0) {
  stop(
    "The following required environment variables are not set:\n",
    paste0("  - ", missing_vars, collapse = "\n"),
    "\n\nSee .env.example for the full list and descriptions.\n",
    "For local development, copy .env.example to .env and fill in values.\n",
    call. = FALSE
  )
}

# ---- Assign to named constants ----
# Use UPPER_CASE for configuration constants so they are visually distinct
# from local variables (which use snake_case) in scripts.

GCP_PROJECT_ID  <- Sys.getenv("GCP_PROJECT_ID")
BQ_DATASET      <- Sys.getenv("BQ_DATASET")
GCS_DATA_BUCKET <- Sys.getenv("GCS_DATA_BUCKET")

# Optional: override the source table name (defaults to "referrals")
BQ_SOURCE_TABLE <- Sys.getenv("BQ_SOURCE_TABLE", unset = "referrals")
BQ_OUTPUT_TABLE <- Sys.getenv("BQ_OUTPUT_TABLE", unset = "monthly_rates")

message(
  "Config loaded: project=", GCP_PROJECT_ID,
  "  dataset=", BQ_DATASET,
  "  source=", BQ_SOURCE_TABLE
)
