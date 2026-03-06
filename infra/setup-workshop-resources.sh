#!/usr/bin/env bash
# infra/setup-workshop-resources.sh
#
# Sets up the GCP infrastructure required for the RAP Workshop.
# This script creates:
#   - A BigQuery dataset for surveillance data
#   - A GCS bucket for code/data exchange
#   - A Secret Manager entry for the PIPELINE_SALT

set -euo pipefail

# ---- Configuration ----
PROJECT_ID=$(gcloud config get-value project)
LOCATION="europe-west2"
DATASET_NAME="workshop_surveillance"
BUCKET_NAME="workshop-data-${PROJECT_ID}"
SECRET_NAME="PIPELINE_SALT"

echo "============================================"
echo "RAP Workshop Infrastructure Setup"
echo "Project:  ${PROJECT_ID}"
echo "Location: ${LOCATION}"
echo "============================================"

# 1. Enable APIs
echo ""
echo "Enabling GCP APIs..."
gcloud services enable \
  run.googleapis.com \
  bigquery.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com

# 2. Create BigQuery Dataset
echo ""
echo "Creating BigQuery dataset: ${DATASET_NAME}"
if ! bq ls --project_id "${PROJECT_ID}" | grep -q "${DATASET_NAME}"; then
  bq mk --project_id "${PROJECT_ID}" --location "${LOCATION}" --dataset "${DATASET_NAME}"
else
  echo "Dataset already exists."
fi

# 3. Create GCS Bucket
echo ""
echo "Creating GCS bucket: gs://${BUCKET_NAME}"
if ! gcloud storage buckets list "gs://${BUCKET_NAME}" &>/dev/null; then
  gcloud storage buckets create "gs://${BUCKET_NAME}" --location="${LOCATION}" --uniform-bucket-level-access
else
  echo "Bucket already exists."
fi

# 4. Create Secret Manager Entry
echo ""
echo "Creating secret: ${SECRET_NAME}"
if ! gcloud secrets list --filter="name ~ ${SECRET_NAME}" | grep -q "${SECRET_NAME}"; then
  echo -n "analyst_secret_salt_2026" | \
    gcloud secrets create "${SECRET_NAME}" \
      --data-file=- \
      --replication-policy="automatic"
else
  echo "Secret already exists."
fi

# 5. Create a Workshop Service Account
SA_NAME="workshop-analyst-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo ""
echo "Setting up Workshop Service Account: ${SA_EMAIL}"
if ! gcloud iam service-accounts describe "${SA_EMAIL}" &>/dev/null; then
  gcloud iam service-accounts create "${SA_NAME}" --display-name="Workshop Analyst SA"
fi

# Grant permissions
echo "Granting IAM roles..."
# BigQuery
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.jobUser"

# Storage
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"

# Secret Manager
gcloud secrets add-iam-policy-binding "${SECRET_NAME}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

echo ""
echo "============================================"
echo "Workshop setup complete!"
echo "Bucket:  gs://${BUCKET_NAME}"
echo "Dataset: ${DATASET_NAME}"
echo "SA:      ${SA_EMAIL}"
echo "============================================"
