#!/bin/bash
# run.sh
#
# Pipeline entrypoint. This script is called by:
#   - Cloud Run Job (via the job's command override)
#   - docker compose locally (via the command in docker-compose.yml)
#
# Edit the steps below to match your pipeline's execution order.
# Scripts are sourced from /workspace, which is:
#   - Locally: your project directory, bind-mounted by docker compose
#   - Cloud Run: the GCS bucket subfolder for this repo, mounted as a volume

set -euo pipefail

echo "Pipeline started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------------------------------------------------------------------------
# Step 1: Extract  (R)
# ---------------------------------------------------------------------------
echo "--- extract ---"
Rscript /workspace/src/extract.R

# ---------------------------------------------------------------------------
# Step 2: Transform  (Python)
# ---------------------------------------------------------------------------
echo "--- transform ---"
python /workspace/src/transform.py

# ---------------------------------------------------------------------------
# Step 3: Load  (R)
# ---------------------------------------------------------------------------
echo "--- load ---"
Rscript /workspace/src/load.R

echo "Pipeline complete: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
