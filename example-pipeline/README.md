# example-pipeline: AMR Surveillance

A fully-worked example of an analytical pipeline built with the `gcp-etl`
Docker image. This is the companion code to the
[R to the Cloud](https://ch3w3y.github.io/docker_gcp) documentation.

**What the pipeline does**: calculates monthly antimicrobial resistance (AMR)
rates for five key organisms across five countries, producing a 12-month
time series suitable for public health surveillance reporting.

**Organisms tracked**: *E. coli*, *K. pneumoniae*, *S. aureus* (MRSA),
*P. aeruginosa*, *A. baumannii*

**Countries**: United Kingdom, Germany, France, Italy, Spain

Every concept described in the documentation is demonstrated here — read the
code alongside the relevant docs page.

---

## What this demonstrates

| Concept | Documentation page | Where in this repo |
|---|---|---|
| Environment variables | [Making Code GitHub-Ready](../docs/code-readiness.md) | `config.R`, `.env.example` |
| R functions with roxygen2 | [Building R Packages](../docs/r-packages.md) | `R/*.R` |
| Python + R bilingual pipeline | [Containers Explained](../docs/docker-containers.md) | `src/transform.py` |
| Thin orchestration scripts | [Organising Your R Code](../docs/code-organisation.md) | `src/*.R` |
| Unit tests with testthat | [Writing Tests](../docs/testing-guide.md) | `tests/testthat/` |
| pytest tests for Python | [Writing Tests](../docs/testing-guide.md) | `tests/test_transform.py` |
| Pipeline orchestration | [How the Pipeline Works](../docs/architecture.md) | `run.sh` |
| renv lock file | [Managing R & Python Versions](../docs/version-management.md) | `renv.lock` |

---

## Running locally

**Prerequisites**: WSL2 with Docker running. Authenticate to GCP:

```bash
gcloud auth application-default login
```

```bash
# Navigate to this directory inside WSL2
cd ~/projects/docker_gcp/example-pipeline

# Copy and fill in the environment file
cp .env.example .env
# Edit .env — at minimum set GCP_PROJECT_ID, BQ_DATASET, GCS_DATA_BUCKET

# Run the full pipeline
docker compose run --rm pipeline

# Open an interactive shell to explore
docker compose run --rm pipeline bash

# Run R tests only
docker compose run --rm pipeline \
  Rscript -e "testthat::test_dir('tests/testthat', reporter='progress')"

# Run Python tests only
docker compose run --rm pipeline pytest tests/ -v
```

---

## Pipeline steps

```
run.sh
├── src/extract.R        R: fetch isolate records from BigQuery
├── src/transform.py     Python: calculate resistance rates + trends
└── src/load.R           R: write monthly summary to BigQuery and GCS
```

## Directory structure

```
example-pipeline/
├── run.sh               pipeline entrypoint
├── config.R             environment variable validation
├── DESCRIPTION          R package metadata and dependencies
│
├── R/                   R package functions (with roxygen2 documentation)
│   ├── extract.R        fetch_isolates(), validate_extract()
│   ├── transform.R      clean_isolates(), calculate_resistance_rates()
│   ├── load.R           write_amr_summary()
│   └── utils.R          bq_table_id(), validate_columns(), log_message()
│
├── src/                 thin orchestration scripts
│   ├── extract.R        source R/ functions, fetch data, write to /tmp
│   ├── transform.py     pandas: aggregate + Mann-Kendall trend test
│   └── load.R           source R/ functions, write to BigQuery and GCS
│
├── tests/
│   ├── testthat/        R unit tests
│   │   ├── setup.R
│   │   ├── test-transform.R
│   │   └── test-extract.R
│   └── test_transform.py  Python unit tests
│
├── .env.example         required environment variables (no real values)
├── docker-compose.yml   local container setup
└── requirements.txt     pinned Python packages
```
