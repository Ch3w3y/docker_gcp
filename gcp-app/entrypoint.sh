#!/bin/bash
# entrypoint.sh
#
# Selects the runtime framework based on the APP_TYPE environment variable.
#
# APP_TYPE=dash   (default) — starts the Dash app via gunicorn
# APP_TYPE=shiny            — starts the Shiny app via Rscript
#
# Set APP_TYPE in Cloud Run environment variables when deploying.
# The PORT variable is injected automatically by Cloud Run (default: 8080).

set -euo pipefail

PORT="${PORT:-8080}"
APP_TYPE="${APP_TYPE:-dash}"

if [ "$APP_TYPE" = "shiny" ]; then
    echo "Starting Shiny app on port ${PORT}..."
    exec Rscript -e "shiny::runApp('app', host='0.0.0.0', port=${PORT})"
else
    echo "Starting Dash app on port ${PORT} (workers: 2)..."
    exec gunicorn \
        --bind "0.0.0.0:${PORT}" \
        --workers 2 \
        --timeout 120 \
        app:server
fi
