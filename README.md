# GCP Cloud Run Pipeline Boilerplate

Bilingual (Python + R) Docker images and a complete local-to-cloud deployment
pattern for data pipelines on Google Cloud Platform.

This repo serves two audiences:

| You are... | Start here |
|---|---|
| An **analyst or data scientist** writing pipeline code | [How it works](./docs/architecture.md), then [WSL2 setup](./docs/wsl-setup.md) |
| A **platform or infrastructure engineer** deploying pipelines | [GCP deployment guide](./docs/gcp-deployment.md) |
| **New to Git and GitHub** | [Git workflow guide](./docs/git-workflow.md) |

---

## What this repo provides

| Component | Purpose |
|---|---|
| `gcp-etl` image | Base environment for Cloud Run Jobs — ETL pipelines, analysis, reporting |
| `gcp-app` image | Base environment for Cloud Run Services — Dash and Shiny dashboards |
| `pipeline-template/` | Starting point for a new analyst pipeline project |
| `docs/` | Architecture, setup guides, workflow references |
| GitHub Actions workflows | Automated tests on PRs, image builds on merge, GCS sync template |

---

## The core idea

Your pipeline code never lives inside the Docker image. The image contains
only the tools (Python, R, and packages). Your code is mounted in at runtime
from a local folder or a GCS bucket, always at `/workspace`.

```
Local development                   Cloud Run Job
─────────────────────────────────   ──────────────────────────────────────
Your project folder                 GCS bucket subfolder
  ./my-pipeline/              →       gs://dept-code/my-pipeline/
        │                                         │
        └───────── mounted at /workspace ─────────┘
                          │
                    bash run.sh
```

This means:
- You never rebuild the Docker image when you change your pipeline code
- Your local environment and the cloud environment are identical
- Switching between projects is a matter of changing which folder is mounted

See [docs/architecture.md](./docs/architecture.md) for a full explanation with diagrams.

---

## Recommended reading order

If you are new to this setup, work through the documentation in this order:

1. **[docs/architecture.md](./docs/architecture.md)** — understand how the system fits together before touching anything
2. **[docs/wsl-setup.md](./docs/wsl-setup.md)** — set up your Windows environment (Linux and Docker)
3. **[docs/positron-setup.md](./docs/positron-setup.md)** — set up Positron with the devcontainer
4. **[docs/git-workflow.md](./docs/git-workflow.md)** — learn the branch-and-pull-request workflow
5. **[docs/testing-guide.md](./docs/testing-guide.md)** — write and run unit tests for your pipeline
6. Come back here for the quick start below

---

## Repository structure

```
docker_gcp/
│
├── .devcontainer/
│   └── devcontainer.json         Opens the project inside the gcp-etl container.
│                                 Gives you the same Python/R environment as Cloud Run.
│
├── .github/
│   └── workflows/
│       ├── build-push.yml        Builds and pushes gcp-etl and gcp-app images to
│       │                         Artifact Registry and GHCR when Dockerfiles change.
│       ├── test.yml              Runs pytest and testthat on every pull request.
│       └── sync-to-gcs.yml      Template: copy this into a pipeline repo to sync
│                                 code to GCS on merge to main.
│
├── docs/
│   ├── architecture.md           How the whole system fits together. Start here.
│   ├── wsl-setup.md              Setting up WSL2 on Windows 11 Enterprise.
│   ├── positron-setup.md         Connecting Positron to WSL2 and devcontainers.
│   ├── git-workflow.md           Git branching and pull request workflow.
│   ├── testing-guide.md          Writing pytest and testthat unit tests.
│   └── gcp-deployment.md         One-time GCP infrastructure setup for platform teams.
│
├── gcp-etl/
│   ├── Dockerfile                Ubuntu 24.04 + Python 3.12 + R 4.5 + ETL packages.
│   ├── requirements.txt          Python packages: GCP clients, pandas, matplotlib.
│   ├── renv.lock                 R package versions, locked for reproducibility.
│   └── install_base_packages.R   Installs R packages and regenerates renv.lock.
│
├── gcp-app/
│   ├── Dockerfile                Extends gcp-etl with Dash and Shiny packages.
│   ├── requirements.txt          Adds: dash, plotly, gunicorn.
│   ├── renv.lock                 Adds: shiny, bslib, DT, plotly.
│   ├── install_base_packages.R   Installs R packages and regenerates renv.lock.
│   └── entrypoint.sh             Starts Dash or Shiny based on APP_TYPE env var.
│
├── pipeline-template/            Copy this directory to start a new pipeline project.
│   ├── .env.example              Document all required env vars here. Analysts copy
│   │                             this to .env and fill in local values.
│   ├── docker-compose.yml        Runs run.sh locally with a bind mount at /workspace.
│   ├── run.sh                    Pipeline entrypoint. Defines step execution order.
│   ├── cloud-run-job.yml         Cloud Run Job spec. Fill in and hand to platform team.
│   ├── src/
│   │   ├── extract.R             Example R extract step (BigQuery → memory).
│   │   ├── transform.py          Example Python transform step.
│   │   └── load.R                Example R load step (memory → BigQuery/GCS).
│   └── tests/
│       ├── test_pipeline.py      pytest unit tests for Python functions.
│       └── testthat/
│           └── test_pipeline.R   testthat unit tests for R functions.
│
├── .gitignore
└── README.md
```

---

## Quick start: run a pipeline locally

### Prerequisites

- WSL2 with Ubuntu (see [docs/wsl-setup.md](./docs/wsl-setup.md))
- Docker Desktop with WSL2 integration enabled
- Positron or VS Code (see [docs/positron-setup.md](./docs/positron-setup.md))

### Steps

```bash
# Clone the repo (run this inside your WSL2 Ubuntu terminal)
git clone https://github.com/Ch3w3y/docker_gcp.git
cd docker_gcp/pipeline-template

# Set up your local environment variables
cp .env.example .env
# Edit .env with your project values

# Pull the base image and run the pipeline
docker compose up
```

This runs `run.sh` inside the `gcp-etl` container with your local project
folder mounted at `/workspace`. The execution path is identical to Cloud Run.

To open an interactive shell inside the container for debugging:

```bash
docker compose run --rm pipeline bash
```

---

## Quick start: build the base images locally

Only needed if you are developing the base images themselves.

```bash
docker build -t gcp-etl:local ./gcp-etl
docker build -t gcp-app:local ./gcp-app

# Smoke test
docker run --rm gcp-etl:local python --version
docker run --rm gcp-etl:local Rscript --version
docker run --rm gcp-etl:local python -c "import pandas; print(pandas.__version__)"
docker run --rm gcp-etl:local Rscript -e "library(tidyverse); cat('tidyverse OK\n')"
```

---

## Starting a new pipeline project

1. Copy `pipeline-template/` into a new repository
2. Copy `.env.example` → `.env` and fill in your values
3. Edit `run.sh` to define your pipeline's execution order
4. Write your scripts in `src/`
5. Write unit tests in `tests/` (see [docs/testing-guide.md](./docs/testing-guide.md))
6. Copy `.github/workflows/sync-to-gcs.yml` into your repo's workflows
7. Fill in `cloud-run-job.yml` and hand it to your platform team

---

## Adding packages to the base images

### Python

Add to `gcp-etl/requirements.txt` or `gcp-app/requirements.txt` and open a
pull request against this repo. The image rebuilds automatically on merge.

### R

1. Add the package name to `install_base_packages.R`
2. Regenerate `renv.lock`:

```bash
docker build -t gcp-etl:local ./gcp-etl
docker run --rm -v $(pwd)/gcp-etl:/out gcp-etl:local \
  Rscript install_base_packages.R --snapshot /out/renv.lock
```

3. Commit the updated `renv.lock` and open a pull request

---

## CI/CD overview

| Trigger | Workflow | What it does |
|---|---|---|
| Pull request to `main` | `test.yml` | Runs pytest and testthat |
| Merge to `main` (Dockerfile changed) | `build-push.yml` | Builds and pushes images to Artifact Registry and GHCR |
| Merge to `main` (pipeline repo) | `sync-to-gcs.yml` | Syncs code to GCS code bucket |

### GitHub Secrets required

| Secret | Description |
|---|---|
| `GCP_PROJECT_ID` | GCP project ID |
| `GCP_REGION` | Artifact Registry region (e.g. `europe-west2`) |
| `GCP_AR_REPO` | Artifact Registry repository name |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider resource name (preferred auth method) |
| `GCP_SERVICE_ACCOUNT` | Service account email for WIF |
| `GCP_SA_KEY` | Base64-encoded SA key JSON (fallback if WIF not configured) |
| `GCS_CODE_BUCKET` | GCS bucket name for synced pipeline code |

---

## Included packages

### gcp-etl

| Language | Packages |
|---|---|
| Python | `google-cloud-bigquery[pandas]`, `google-cloud-storage`, `google-auth`, `pandas`, `pyarrow`, `db-dtypes`, `openpyxl`, `matplotlib`, `seaborn` |
| R | `bigrquery`, `googleCloudStorageR`, `gargle`, `tidyverse`, `DBI`, `lubridate`, `janitor`, `openxlsx`, `rmarkdown`, `knitr` |

### gcp-app (extends gcp-etl)

| Language | Additional packages |
|---|---|
| Python | `dash`, `dash-bootstrap-components`, `plotly`, `gunicorn` |
| R | `shiny`, `bslib`, `DT`, `plotly`, `shinycssloaders` |

---

## Further reading

- [docs/architecture.md](./docs/architecture.md) — how all the pieces fit together
- [docs/wsl-setup.md](./docs/wsl-setup.md) — Windows 11 Enterprise setup guide
- [docs/positron-setup.md](./docs/positron-setup.md) — IDE setup with WSL2 and devcontainers
- [docs/git-workflow.md](./docs/git-workflow.md) — branch and pull request workflow
- [docs/testing-guide.md](./docs/testing-guide.md) — writing and running tests
- [docs/gcp-deployment.md](./docs/gcp-deployment.md) — infrastructure setup for platform teams
