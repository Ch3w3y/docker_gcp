#!/usr/bin/env bash
# infra/setup-demo-bucket.sh
#
# One-time setup: creates a public GCS bucket for demo outputs and configures
# IAM to allow public read access.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated: gcloud auth login
#   - Owner or Editor role on the GCP project
#
# Usage:
#   export GCP_PROJECT_ID=your-project-id
#   export GCS_DEMO_BUCKET=your-demo-outputs-bucket   # must be globally unique
#   bash infra/setup-demo-bucket.sh

set -euo pipefail

# ── Validate inputs ────────────────────────────────────────────────────────────

if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  echo "ERROR: GCP_PROJECT_ID is not set."
  echo "  Run: export GCP_PROJECT_ID=your-project-id"
  exit 1
fi

if [[ -z "${GCS_DEMO_BUCKET:-}" ]]; then
  echo "ERROR: GCS_DEMO_BUCKET is not set."
  echo "  Run: export GCS_DEMO_BUCKET=your-demo-outputs-bucket"
  exit 1
fi

LOCATION="${GCS_DEMO_LOCATION:-europe-west2}"

echo "=================================================="
echo " GCP Demo Bucket Setup"
echo "=================================================="
echo " Project  : ${GCP_PROJECT_ID}"
echo " Bucket   : gs://${GCS_DEMO_BUCKET}"
echo " Location : ${LOCATION}"
echo "=================================================="
echo ""
echo "This will create a PUBLIC GCS bucket."
echo "All objects uploaded will be readable by anyone with the URL."
echo ""
read -r -p "Continue? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# ── Enable required APIs ───────────────────────────────────────────────────────

echo ""
echo "Enabling GCS API..."
gcloud services enable storage.googleapis.com \
  --project="${GCP_PROJECT_ID}" \
  --quiet

# ── Create the bucket ─────────────────────────────────────────────────────────

echo "Creating bucket: gs://${GCS_DEMO_BUCKET}"

if gcloud storage buckets describe "gs://${GCS_DEMO_BUCKET}" \
    --project="${GCP_PROJECT_ID}" > /dev/null 2>&1; then
  echo "  Bucket already exists — skipping creation."
else
  gcloud storage buckets create "gs://${GCS_DEMO_BUCKET}" \
    --project="${GCP_PROJECT_ID}" \
    --location="${LOCATION}" \
    --uniform-bucket-level-access \
    --no-public-access-prevention
  echo "  Bucket created."
fi

# ── Grant public read access ───────────────────────────────────────────────────

echo "Granting public read access (allUsers:objectViewer)..."
gcloud storage buckets add-iam-policy-binding "gs://${GCS_DEMO_BUCKET}" \
  --member="allUsers" \
  --role="roles/storage.objectViewer"
echo "  Public access granted."

# ── Enable CORS for browser access ────────────────────────────────────────────
# Allows the bucket objects to be embedded in web pages without CORS errors.

CORS_FILE=$(mktemp /tmp/cors.XXXXXX.json)
cat > "${CORS_FILE}" << 'EOF'
[
  {
    "origin": ["*"],
    "method": ["GET"],
    "responseHeader": ["Content-Type", "Content-Disposition"],
    "maxAgeSeconds": 3600
  }
]
EOF

echo "Configuring CORS..."
gcloud storage buckets update "gs://${GCS_DEMO_BUCKET}" \
  --cors-file="${CORS_FILE}"
rm "${CORS_FILE}"
echo "  CORS configured."

# ── Create placeholder README ─────────────────────────────────────────────────

echo "Uploading bucket README..."
TMP_README=$(mktemp /tmp/README.XXXXXX.txt)
cat > "${TMP_README}" << EOF
AMR Surveillance Demo Outputs
==============================

This bucket contains demonstration outputs from the R to the Cloud guide:
https://ch3w3y.github.io/docker_gcp

Files in amr-demo/ are generated from synthetic data using ggplot2.
They are intended for learning purposes only and do not represent real surveillance data.

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Project:   ${GCP_PROJECT_ID}
EOF

gcloud storage cp "${TMP_README}" "gs://${GCS_DEMO_BUCKET}/README.txt"
rm "${TMP_README}"

# ── Final summary ─────────────────────────────────────────────────────────────

echo ""
echo "=================================================="
echo " Setup complete."
echo "=================================================="
echo ""
echo "Next steps:"
echo ""
echo "  1. Generate demo outputs:"
echo "     Rscript demo/generate_amr_outputs.R"
echo ""
echo "  2. Upload to GCS:"
echo "     export GCS_DEMO_BUCKET=${GCS_DEMO_BUCKET}"
echo "     Rscript demo/upload_to_gcs.R"
echo ""
echo "  3. Access via URL:"
echo "     https://storage.googleapis.com/${GCS_DEMO_BUCKET}/amr-demo/"
echo ""
echo "  4. To automate generation on push, add to GitHub Secrets:"
echo "     GCS_DEMO_BUCKET=${GCS_DEMO_BUCKET}"
echo "     GCP_PROJECT_ID=${GCP_PROJECT_ID}"
echo ""
