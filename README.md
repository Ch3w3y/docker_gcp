# R to the Cloud

**A practical guide for public sector R analysts moving from local R and RStudio to GitHub, Docker, and Google Cloud Platform.**

No prior DevOps experience needed. Starts from version control basics and works up to automated cloud pipelines.

**[Read the full guide →](https://ch3w3y.github.io/docker_gcp)**

---

## Who this is for

R analysts in the public sector who currently:

- Write analysis in RMarkdown notebooks or long scripts
- Share work via Samba shares or email attachments
- Track versions with filenames like `analysis_v2_FINAL_USE_THIS_ONE.R`
- Want to move to reproducible, auditable, cloud-deployed pipelines

---

## What the guide covers

| Section | Topics |
|---|---|
| **Why Change?** | The case for modern workflows; Samba shares vs Git |
| **Git & GitHub** | Version control from scratch; branching; pull requests |
| **Linux & WSL2** | What Linux is; setting up WSL2 on Windows; Positron IDE |
| **Docker & Environments** | Containers explained; managing R package versions with renv |
| **From Notebooks to Pipelines** | Organising R code; sanitising code for GitHub; R packages; testing |
| **Worked Example** | A complete AMR surveillance pipeline in pure R |
| **Cloud Deployment** | How the pipeline architecture works; deploying to GCP Cloud Run |

---

## The worked example

[`example-pipeline/`](./example-pipeline/) contains a complete, runnable AMR (antimicrobial resistance) surveillance pipeline:

- Extracts monthly isolate data from BigQuery
- Calculates resistance rates for 5 organisms across 5 European countries
- Produces a 12-month time series for public health reporting
- Writes output back to BigQuery (long format + wide matrix)

The pipeline is structured as an R package with:

```
example-pipeline/
├── R/                    Business logic — pure functions, fully testable
│   ├── extract.R         AMR_ORGANISMS and AMR_COUNTRIES constants; fetch + validate
│   ├── transform.R       clean → calculate rates → flag breaches → pivot wide
│   ├── load.R            Write to BigQuery (summary + matrix tables)
│   └── utils.R           Internal helpers (logging, column validation)
├── src/                  Thin orchestration scripts — call R/ functions in order
│   ├── extract.R
│   ├── transform.R
│   └── load.R
├── tests/testthat/       32 unit tests — no BigQuery connection required
│   ├── setup.R           Test fixtures: make_test_isolates(), make_clean_isolates()
│   ├── test-extract.R    Constants and validate_extract() tests
│   └── test-transform.R  All transform function tests
├── config.R              Validates required env vars at startup; fails fast
├── run.sh                Pipeline entrypoint — calls src/ steps in sequence
├── DESCRIPTION           R package metadata
├── docker-compose.yml    Run locally with gcp-etl image and ADC credentials
└── .env.example          Required environment variables (copy to .env)
```

**You do not need a BigQuery connection to explore the code.** The test fixtures create synthetic data locally — see [the walkthrough](https://ch3w3y.github.io/docker_gcp/example-walkthrough/) for a local exploration session.

---

## Running the example locally

### Prerequisites

- WSL2 with Ubuntu ([setup guide](https://ch3w3y.github.io/docker_gcp/wsl-setup/))
- Docker Desktop with WSL2 integration enabled
- The `gcp-etl` base image built locally

```bash
# Build the base image
docker build -t gcp-etl:local ./gcp-etl

# Clone this repo inside WSL2
git clone https://github.com/Ch3w3y/docker_gcp.git
cd docker_gcp/example-pipeline

# Set up environment variables
cp .env.example .env
# Edit .env with your GCP project values

# Run the full pipeline
docker compose run --rm pipeline

# Or open an interactive shell for exploration
docker compose run --rm pipeline bash
```

### Run tests without BigQuery

```bash
docker compose run --rm pipeline \
  Rscript -e "testthat::test_dir('tests/testthat', reporter='progress')"
```

---

## Repository structure

```
docker_gcp/
├── docs/                 Markdown source for the guide (built by MkDocs)
├── example-pipeline/     Complete AMR surveillance pipeline (see above)
├── gcp-etl/              Base Docker image for Cloud Run Jobs
│   ├── Dockerfile        Ubuntu 24.04 + Python 3.12 + R 4.5 + ETL packages
│   ├── requirements.txt  Pinned Python packages
│   └── renv.lock         Locked R package versions
├── gcp-app/              Docker image for Cloud Run Services (Dash + Shiny)
│   ├── Dockerfile        Extends gcp-etl
│   ├── requirements.txt  Adds dash, plotly, gunicorn
│   ├── renv.lock         Adds shiny, bslib, DT, plotly
│   └── entrypoint.sh     Starts Dash or Shiny based on APP_TYPE
├── .github/workflows/
│   ├── build-push.yml    Builds and pushes images to Artifact Registry on merge
│   ├── test.yml          Runs testthat on every pull request
│   └── deploy-docs.yml   Publishes the guide to GitHub Pages
├── mkdocs.yml            Documentation site configuration
└── README.md             This file
```

---

## Base images

The `gcp-etl` image is the runtime environment used by `example-pipeline/`:

| Language | Included packages |
|---|---|
| R | `bigrquery`, `googleCloudStorageR`, `gargle`, `tidyverse`, `DBI`, `lubridate`, `janitor`, `openxlsx`, `rmarkdown`, `knitr`, `testthat`, `devtools` |
| Python | `google-cloud-bigquery[pandas]`, `google-cloud-storage`, `pandas`, `pyarrow`, `openpyxl` |

The `gcp-app` image extends `gcp-etl` with dashboard packages (`shiny`, `bslib`, `dash`, `plotly`, `gunicorn`) and is suitable for Cloud Run Services.

---

## Documentation site

The guide is published at **[https://ch3w3y.github.io/docker_gcp](https://ch3w3y.github.io/docker_gcp)** and built automatically from `docs/` using [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

To preview locally:

```bash
pip install mkdocs-material
mkdocs serve
# Open http://127.0.0.1:8000
```

---

## Contributing

Spotted an error or want to add a section? Open a pull request — the [Git & GitHub](https://ch3w3y.github.io/docker_gcp/git-workflow/) section of the guide covers exactly how to do that.
