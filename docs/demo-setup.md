# Demo Resources Setup

This page describes the demonstration GCS bucket that accompanies the guide — a public Google Cloud Storage bucket containing ggplot2 outputs generated from synthetic AMR surveillance data. Colleagues can view the outputs without needing a GCP account.

It also serves as a worked example of the [Generating and Sharing Outputs](outputs-and-reporting.md) pattern described earlier in the guide.

---

## What the demo provides

A public GCS bucket containing four publication-ready ggplot2 outputs, regenerated automatically each month:

| Figure | Description | Formats |
|---|---|---|
| `figure_01_resistance_trends` | 12-month resistance trend lines for all five organisms, faceted by country | PDF, PNG |
| `figure_02_country_heatmap` | Mean resistance rate heatmap (organism × country) | PDF, PNG |
| `figure_03_breach_overview` | Proportion of months above the 50% alert threshold | PDF, PNG |
| `figure_04_organism_distribution` | Violin plots of monthly resistance rate distribution | PDF, PNG |

All outputs are generated from synthetic data and are intended for learning purposes only. They do not represent real surveillance data.

---

## Accessing the demo outputs

Once the bucket is set up and the workflow has run, outputs are available via public URL:

```
https://storage.googleapis.com/GCS_DEMO_BUCKET/amr-demo/figure_01_resistance_trends.pdf
https://storage.googleapis.com/GCS_DEMO_BUCKET/amr-demo/figure_01_resistance_trends.png
https://storage.googleapis.com/GCS_DEMO_BUCKET/amr-demo/figure_02_country_heatmap.pdf
...
```

Replace `GCS_DEMO_BUCKET` with the actual bucket name for your deployment.

!!! tip "Sharing with colleagues"
    These URLs work in any browser without a Google account. Share them directly — colleagues can click the PDF link to view or download the report.

---

## One-time setup (platform team)

### Prerequisites

- GCP project with billing enabled
- `gcloud` CLI installed and authenticated: `gcloud auth login`
- GitHub Secrets already configured for WIF (see [GCP Deployment](gcp-deployment.md))

### Step 1: Create the public GCS bucket

```bash
# Set your project and choose a globally-unique bucket name
export GCP_PROJECT_ID=your-project-id
export GCS_DEMO_BUCKET=amr-demo-outputs-yourproject   # must be globally unique

# Run the setup script (creates bucket, sets public IAM, configures CORS)
bash infra/setup-demo-bucket.sh
```

The script will ask for confirmation before making the bucket public. It sets:

- Uniform bucket-level access (recommended)
- `allUsers:objectViewer` IAM — anyone with a URL can read objects
- CORS headers for browser access

!!! warning "Public bucket — appropriate for demo data only"
    Never upload sensitive or patient-identifiable data to this bucket. It is intended exclusively for aggregated, synthetic demonstration outputs.

### Step 2: Add GitHub Secrets

In the repository settings (**Settings > Secrets and variables > Actions**), add:

| Secret name | Value |
|---|---|
| `GCS_DEMO_BUCKET` | The bucket name you created |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider (same as for other workflows) |
| `GCP_SERVICE_ACCOUNT` | Service account email with GCS write access |

The service account needs `roles/storage.objectAdmin` on the demo bucket:

```bash
gcloud storage buckets add-iam-policy-binding "gs://${GCS_DEMO_BUCKET}" \
  --member="serviceAccount:YOUR_SERVICE_ACCOUNT_EMAIL" \
  --role="roles/storage.objectAdmin"
```

### Step 3: Trigger the first run

Navigate to **Actions > Generate and publish demo outputs > Run workflow**.

The workflow:

1. Installs R and the required packages
2. Sources the example pipeline functions (`example-pipeline/R/`)
3. Generates synthetic AMR data and runs it through the pipeline
4. Saves four ggplot2 figures as PDF and PNG
5. Uploads to GCS and prints the public URLs in the job log

After the first run, it reruns automatically:

- **On push** — when `demo/generate_amr_outputs.R` or the example pipeline R functions change
- **Monthly** — on the 1st of each month at 06:00 UTC

---

## Generating outputs locally

You do not need a GCP account to generate the figures locally. From the repository root:

```bash
# Install required R packages (if not already available)
Rscript -e "install.packages(c('ggplot2','dplyr','tidyr','lubridate','scales','glue','purrr'))"

# Generate all four figures
Rscript demo/generate_amr_outputs.R
```

Outputs are saved to `demo/outputs/`.

To upload them to GCS after generating locally:

```bash
export GCS_DEMO_BUCKET=your-bucket-name
Rscript demo/upload_to_gcs.R
```

---

## How the demo is structured

The demo directory demonstrates the [Generating and Sharing Outputs](outputs-and-reporting.md) pattern from the guide:

```
demo/
├── generate_amr_outputs.R   Sources example-pipeline/R/ functions, generates
│                            synthetic data, and saves four ggplot2 figures
├── upload_to_gcs.R          Uploads demo/outputs/ to the public GCS bucket
└── outputs/                 Generated files (git-ignored)
    ├── figure_01_resistance_trends.pdf
    ├── figure_01_resistance_trends.png
    ├── figure_02_country_heatmap.pdf
    ├── figure_02_country_heatmap.png
    ├── figure_03_breach_overview.pdf
    ├── figure_03_breach_overview.png
    ├── figure_04_organism_distribution.pdf
    └── figure_04_organism_distribution.png

infra/
└── setup-demo-bucket.sh     One-time bucket creation and IAM setup

.github/workflows/
└── generate-demo-outputs.yml  Automated generation and upload on push/schedule
```

The key design decisions:

1. **No BigQuery connection required** — outputs are generated entirely from synthetic data using the test fixtures in `example-pipeline/R/extract.R`
2. **PDF and PNG** — PDF for presentations and printing (vector, infinitely scalable), PNG for web and email
3. **Public URLs** — no GCP account needed to access the outputs; shareable by URL
4. **Monthly regeneration** — a scheduled GitHub Actions job keeps outputs current without manual intervention

---

## Exercise: adapting the demo for your own pipeline

The pattern in `demo/generate_amr_outputs.R` is directly applicable to your own pipeline:

1. Replace the synthetic data generation with a call to your own transform functions
2. Design your ggplot2 figures to match your organisation's reporting needs
3. Copy `demo/upload_to_gcs.R` into your pipeline's `src/` as `src/report.R`
4. Add `Rscript /workspace/src/report.R` as the final step in your `run.sh`
5. Set `GCS_OUTPUT_BUCKET` in `.env.example` and Secret Manager

Your pipeline then generates and publishes its own outputs automatically every time it runs — no manual export, no email attachment.
