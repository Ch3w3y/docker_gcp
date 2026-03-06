# GCP Cloud Run Docker Boilerplate

Bilingual (Python + R) Docker images for Google Cloud Platform targeting **Cloud Run**.

| Image | Type | Purpose |
|-------|------|---------|
| `gcp-etl` | Cloud Run **Job** | ETL pipelines, analysis scripts, reporting |
| `gcp-app` | Cloud Run **Service** | Dash or Shiny dashboards |

Both images:
- Base OS: `python:3.12-slim` (Debian Bookworm) + R 4.4 from CRAN
- Python deps managed via `venv` + `requirements.txt`
- R deps managed via `renv` + `renv.lock`
- Full GCP integration (BigQuery + GCS) — no auth code needed in your app
- Published to both **GCP Artifact Registry** and **GHCR** via GitHub Actions

---

## Repository Structure

```
docker_gcp/
├── gcp-etl/
│   ├── Dockerfile
│   ├── requirements.txt          # Python: GCP + ETL packages
│   ├── renv.lock                 # R: locked package versions
│   └── install_base_packages.R  # R: installs packages + snapshots lock
├── gcp-app/
│   ├── Dockerfile
│   ├── requirements.txt          # Python: GCP + Dash packages
│   ├── renv.lock                 # R: locked package versions (+ Shiny)
│   ├── install_base_packages.R  # R: installs packages + snapshots lock
│   └── entrypoint.sh            # Selects Dash or Shiny at runtime
└── .github/
    └── workflows/
        └── build-push.yml       # CI/CD: build both images on push to main
```

---

## Quick Start

### 1. Build locally

```bash
docker build -t test-gcp-etl ./gcp-etl
docker build -t test-gcp-app ./gcp-app
```

### 2. Run locally (with a GCP service account key)

```bash
# ETL job — override CMD to run your script
docker run --rm \
  -e GOOGLE_APPLICATION_CREDENTIALS=/secrets/key.json \
  -v /path/to/key.json:/secrets/key.json:ro \
  -v $(pwd)/my_job:/app \
  test-gcp-etl \
  python main.py

# App — Dash (default)
docker run --rm -p 8080:8080 \
  -e APP_TYPE=dash \
  -e GOOGLE_APPLICATION_CREDENTIALS=/secrets/key.json \
  -v /path/to/key.json:/secrets/key.json:ro \
  -v $(pwd)/my_app:/app \
  test-gcp-app

# App — Shiny
docker run --rm -p 8080:8080 \
  -e APP_TYPE=shiny \
  -e GOOGLE_APPLICATION_CREDENTIALS=/secrets/key.json \
  -v /path/to/key.json:/secrets/key.json:ro \
  -v $(pwd)/my_app:/app \
  test-gcp-app
```

---

## Authentication

Authentication is handled automatically by the GCP client libraries — **no auth code needed in your scripts or apps**.

| Environment | How it works |
|-------------|-------------|
| **Cloud Run (recommended)** | Attach a service account to the Cloud Run service/job. ADC picks it up automatically. |
| **Local / SA key** | Set `GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json` at runtime. Mount the key file as a volume or Cloud Run secret. |

### Python example

```python
from google.cloud import bigquery, storage

# No credentials argument needed — ADC handles it
bq = bigquery.Client(project="my-project")
gcs = storage.Client()
```

### R example

```r
library(bigrquery)
library(googleCloudStorageR)

# gargle picks up ADC / GOOGLE_APPLICATION_CREDENTIALS automatically
bq_auth()
gcs_auth()
```

---

## Extending the Images

### Adding Python packages

Edit `requirements.txt` and rebuild:

```txt
# requirements.txt
google-cloud-bigquery[pandas]>=3.27.0
my-new-package>=1.0.0
```

### Adding R packages

1. Add the package name to `install_base_packages.R`
2. Regenerate `renv.lock` inside a container:

```bash
# Build the image first (installs current packages)
docker build -t my-gcp-etl ./gcp-etl

# Run the install script and copy out the new lock file
docker run --rm \
  -v $(pwd)/gcp-etl:/out \
  my-gcp-etl \
  Rscript install_base_packages.R --snapshot /out/renv.lock

# Commit the updated renv.lock
git add gcp-etl/renv.lock && git commit -m "chore: add R package X"
```

> **Note**: The `renv.lock` shipped in this boilerplate is a template with
> representative package versions. Regenerate it for your environment using the
> steps above. Hash validation is disabled in the Dockerfile so the template
> lock file works out of the box; a freshly generated lock will re-enable full
> reproducibility.

---

## GitHub Actions CI/CD

### Required Secrets

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Description | Example |
|--------|-------------|---------|
| `GCP_PROJECT_ID` | GCP project ID | `my-project-123` |
| `GCP_REGION` | Artifact Registry region | `europe-west2` |
| `GCP_AR_REPO` | Artifact Registry repository name | `docker-images` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider resource name (recommended) | `projects/123/locations/global/workloadIdentityPools/github/providers/github` |
| `GCP_SERVICE_ACCOUNT` | Service account email for WIF | `github-actions@my-project.iam.gserviceaccount.com` |
| `GCP_SA_KEY` | Base64-encoded SA JSON key (fallback if WIF not configured) | `$(base64 -w0 key.json)` |

> **WIF vs SA key**: Workload Identity Federation is preferred — it avoids
> storing long-lived credentials as secrets. If `GCP_WORKLOAD_IDENTITY_PROVIDER`
> is set, WIF is used. Otherwise the workflow falls back to `GCP_SA_KEY`.

### Setting Up Workload Identity Federation

```bash
PROJECT_ID="my-project-123"
POOL_NAME="github"
PROVIDER_NAME="github"
SA_EMAIL="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
REPO="my-org/my-repo"

# Create the pool
gcloud iam workload-identity-pools create "${POOL_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions"

# Create the provider
gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_NAME}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${POOL_NAME}" \
  --display-name="GitHub" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Allow the SA to be impersonated by the GitHub repo
POOL_ID=$(gcloud iam workload-identity-pools describe "${POOL_NAME}" \
  --project="${PROJECT_ID}" --location="global" \
  --format="value(name)")

gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/${REPO}"

# Set the secret values
echo "GCP_WORKLOAD_IDENTITY_PROVIDER: ${POOL_ID}/providers/${PROVIDER_NAME}"
echo "GCP_SERVICE_ACCOUNT: ${SA_EMAIL}"
```

### Image Tags

Each successful push to `main` produces four tags per image:

```
REGION-docker.pkg.dev/PROJECT_ID/AR_REPO/IMAGE:latest
REGION-docker.pkg.dev/PROJECT_ID/AR_REPO/IMAGE:sha-ABCDEF7
ghcr.io/GITHUB_ACTOR/IMAGE:latest
ghcr.io/GITHUB_ACTOR/IMAGE:sha-ABCDEF7
```

---

## Deploying to Cloud Run

### ETL Job

```bash
gcloud run jobs create my-etl-job \
  --image "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/gcp-etl:latest" \
  --region "${REGION}" \
  --service-account "${SA_EMAIL}" \
  --command python \
  --args "main.py"

# Execute it
gcloud run jobs execute my-etl-job --region "${REGION}"
```

### Dash App

```bash
gcloud run deploy my-dash-app \
  --image "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/gcp-app:latest" \
  --region "${REGION}" \
  --service-account "${SA_EMAIL}" \
  --set-env-vars APP_TYPE=dash \
  --port 8080 \
  --allow-unauthenticated
```

### Shiny App

```bash
gcloud run deploy my-shiny-app \
  --image "${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/gcp-app:latest" \
  --region "${REGION}" \
  --service-account "${SA_EMAIL}" \
  --set-env-vars APP_TYPE=shiny \
  --port 8080 \
  --allow-unauthenticated
```

---

## Included Packages

### gcp-etl

| Language | Packages |
|----------|---------|
| Python | `google-cloud-bigquery[pandas]`, `google-cloud-storage`, `google-auth`, `pandas`, `pyarrow`, `db-dtypes`, `openpyxl`, `matplotlib`, `seaborn` |
| R | `bigrquery`, `googleCloudStorageR`, `gargle`, `tidyverse`, `DBI`, `lubridate`, `janitor`, `openxlsx`, `rmarkdown`, `knitr` |

### gcp-app (extends gcp-etl)

| Language | Additional packages |
|----------|-------------------|
| Python | `dash`, `dash-bootstrap-components`, `plotly`, `gunicorn` |
| R | `shiny`, `bslib`, `DT`, `plotly`, `shinycssloaders` |

---

## Service Account Permissions

Minimum IAM roles for the Cloud Run service account:

| Role | Purpose |
|------|---------|
| `roles/bigquery.dataViewer` | Read BigQuery tables |
| `roles/bigquery.jobUser` | Run BigQuery jobs (queries) |
| `roles/storage.objectViewer` | Read GCS objects |
| `roles/storage.objectCreator` | Write GCS objects (if needed) |

For the GitHub Actions service account (Artifact Registry push):

| Role | Purpose |
|------|---------|
| `roles/artifactregistry.writer` | Push images to Artifact Registry |
