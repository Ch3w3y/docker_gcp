#!/usr/bin/env Rscript
# demo/upload_to_gcs.R
#
# Uploads demo output files from demo/outputs/ to the public GCS demo bucket.
#
# Prerequisites:
#   1. Run infra/setup-demo-bucket.sh once to create the bucket
#   2. Run demo/generate_amr_outputs.R to generate the files
#   3. Set GCS_DEMO_BUCKET in your environment (or .env):
#        export GCS_DEMO_BUCKET=your-demo-outputs-bucket
#
# Run:
#   Rscript demo/upload_to_gcs.R

suppressPackageStartupMessages(library(googleCloudStorageR))

# ── Configuration ─────────────────────────────────────────────────────────────

bucket <- Sys.getenv("GCS_DEMO_BUCKET")
if (!nzchar(bucket)) {
  stop(
    "GCS_DEMO_BUCKET environment variable is not set.\n",
    "Run: export GCS_DEMO_BUCKET=your-demo-outputs-bucket"
  )
}

out_dir <- "demo/outputs"
if (!dir.exists(out_dir)) {
  stop(
    "demo/outputs/ directory not found.\n",
    "Run: Rscript demo/generate_amr_outputs.R"
  )
}

# ── Upload ────────────────────────────────────────────────────────────────────

files <- list.files(out_dir, full.names = TRUE)
if (length(files) == 0) {
  stop("No files found in demo/outputs/. Run generate_amr_outputs.R first.")
}

cat("Uploading", length(files), "files to gs://", bucket, "/amr-demo/\n\n")

for (f in files) {
  gcs_name <- paste0("amr-demo/", basename(f))

  tryCatch({
    gcs_upload(
      file          = f,
      bucket        = bucket,
      name          = gcs_name,
      predefinedAcl = "bucketLevel"
    )
    cat("  OK  ", gcs_name, "\n")
  }, error = function(e) {
    cat("  FAIL", gcs_name, "-", conditionMessage(e), "\n")
  })
}

# ── Print public URLs ─────────────────────────────────────────────────────────

cat("\nPublic URLs:\n")
for (f in files) {
  gcs_name <- paste0("amr-demo/", basename(f))
  url <- paste0("https://storage.googleapis.com/", bucket, "/", gcs_name)
  cat("  ", url, "\n")
}

cat("\nDone.\n")
