#!/usr/bin/env bash
# run.sh
#
# AMR Surveillance pipeline entrypoint.
#
# This script is the entry point for both local execution (via docker compose)
# and Cloud Run Job execution. It runs the three pipeline steps in sequence
# and stops immediately if any step fails.
#
# set -euo pipefail means:
#   -e  exit immediately if a command fails
#   -u  treat unset variables as errors
#   -o pipefail  fail if any command in a pipe fails

set -euo pipefail

echo "============================================"
echo "AMR Surveillance Pipeline"
echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"

# ---- Step 1: Extract ----
echo ""
echo "--- Step 1/3: Extract ---"
Rscript /workspace/src/extract.R

# ---- Step 2: Transform ----
echo ""
echo "--- Step 2/3: Transform ---"
Rscript /workspace/src/transform.R

# ---- Step 3: Load ----
echo ""
echo "--- Step 3/3: Load ---"
Rscript /workspace/src/load.R

echo ""
echo "============================================"
echo "Pipeline complete: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"
