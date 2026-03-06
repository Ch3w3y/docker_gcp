# src/load.R
#
# Load step: write the transformed data to BigQuery and/or GCS.
# Replace the example table name with your own.

library(bigrquery)
library(googleCloudStorageR)

project <- Sys.getenv("GCP_PROJECT_ID")
dataset <- Sys.getenv("BQ_DATASET")
bucket  <- Sys.getenv("GCS_DATA_BUCKET")

transformed_data <- readRDS("/tmp/transformed_data.rds")

# Write to BigQuery (append mode — change to "WRITE_TRUNCATE" to replace).
cat("Loading data to BigQuery...\n")
bq_table_upload(
  x          = bq_table(project, dataset, "your_output_table"),
  values     = transformed_data,
  write_disposition = "WRITE_APPEND"
)

# Optionally, write a copy to GCS as a dated CSV.
output_path <- sprintf("outputs/%s/data.csv", Sys.Date())
cat(sprintf("Writing to gs://%s/%s\n", bucket, output_path))
googleCloudStorageR::gcs_upload(
  file        = transformed_data,
  bucket      = bucket,
  name        = output_path,
  object_function = function(input, output) write.csv(input, output, row.names = FALSE)
)

cat("Load complete.\n")
