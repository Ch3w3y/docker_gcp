# src/extract.R
#
# Extract step: pull data from BigQuery into local (container) memory.
# Replace the example query with your own.

library(bigrquery)
library(dplyr)

project <- Sys.getenv("GCP_PROJECT_ID")
dataset <- Sys.getenv("BQ_DATASET")

# bigrquery picks up Application Default Credentials automatically.
# Locally: run `gcloud auth application-default login` once.
# Cloud Run: credentials come from the attached service account.
bq_auth(path = Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS", unset = NA))

sql <- glue::glue("
  SELECT *
  FROM `{project}.{dataset}.your_source_table`
  WHERE DATE(created_at) = CURRENT_DATE()
")

cat("Extracting data from BigQuery...\n")
raw_data <- bq_project_query(project, sql) |> bq_table_download()
cat(sprintf("Extracted %d rows.\n", nrow(raw_data)))

# Write to a temporary file so the next step can read it.
# In practice you might write to GCS or pass data differently.
saveRDS(raw_data, "/tmp/raw_data.rds")
