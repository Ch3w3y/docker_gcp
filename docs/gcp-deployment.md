# GCP Deployment Guide

This guide covers the one-time infrastructure setup needed before analyst
pipeline repos can be deployed to Cloud Run. It is intended for the platform
or infrastructure team. Analysts do not need to follow these steps.

---

## Prerequisites

- A GCP project with billing enabled
- `gcloud` CLI installed and authenticated: `gcloud auth login`
- The following APIs enabled in your project:

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  cloudscheduler.googleapis.com \
  iam.googleapis.com
```

---

## 1. Create the Artifact Registry repository

This is where built Docker images are stored.

```bash
gcloud artifacts repositories create docker-images \
  --repository-format=docker \
  --location=europe-west2 \
  --description="Base images for Cloud Run pipelines"
```

---

## 2. Create the GCS code bucket

This bucket holds the synced code from each pipeline repo. Each repo gets
its own subfolder.

```bash
gcloud storage buckets create gs://dept-pipeline-code \
  --location=europe-west2 \
  --uniform-bucket-level-access
```

Folder structure after pipelines are synced:

```
gs://dept-pipeline-code/
├── my-pipeline-repo/
│   ├── run.sh
│   └── src/
├── another-pipeline/
│   ├── run.sh
│   └── src/
```

---

## 3. Set up the GitHub Actions service account

This account is used by GitHub Actions to push images to Artifact Registry
and sync code to GCS.

```bash
PROJECT_ID="your-project-id"
SA_NAME="github-actions"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create the service account
gcloud iam service-accounts create ${SA_NAME} \
  --project=${PROJECT_ID} \
  --display-name="GitHub Actions"

# Grant permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer"

gcloud storage buckets add-iam-policy-binding gs://dept-pipeline-code \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"
```

### Set up Workload Identity Federation (preferred over SA keys)

WIF allows GitHub Actions to authenticate to GCP without storing a long-lived
key as a GitHub secret.

```bash
REPO="Ch3w3y/docker_gcp"  # or the analyst's repo

# Create the identity pool
gcloud iam workload-identity-pools create "github" \
  --project=${PROJECT_ID} \
  --location="global" \
  --display-name="GitHub Actions"

# Create the OIDC provider
gcloud iam workload-identity-pools providers create-oidc "github" \
  --project=${PROJECT_ID} \
  --location="global" \
  --workload-identity-pool="github" \
  --display-name="GitHub" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Allow the SA to be used by the specific GitHub repo
POOL_ID=$(gcloud iam workload-identity-pools describe "github" \
  --project=${PROJECT_ID} --location="global" \
  --format="value(name)")

gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --project=${PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/${REPO}"

# Output the values to set as GitHub secrets
echo "GCP_WORKLOAD_IDENTITY_PROVIDER: ${POOL_ID}/providers/github"
echo "GCP_SERVICE_ACCOUNT: ${SA_EMAIL}"
```

---

## 4. Set up a pipeline service account

Each pipeline runs as its own service account. This limits what a pipeline
can access.

```bash
PIPELINE_NAME="my-pipeline"
PIPELINE_SA="${PIPELINE_NAME}-sa@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create ${PIPELINE_NAME}-sa \
  --project=${PROJECT_ID} \
  --display-name="${PIPELINE_NAME} Cloud Run Job"

# Read the code bucket (for GCS volume mount)
gcloud storage buckets add-iam-policy-binding gs://dept-pipeline-code \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/storage.objectViewer"

# BigQuery access
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/bigquery.jobUser"

# Data bucket access (read/write)
gcloud storage buckets add-iam-policy-binding gs://your-data-bucket \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/storage.objectAdmin"

# Secret Manager access
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 5. Add secrets to Secret Manager

For each variable in the analyst's `.env.example`:

```bash
echo -n "your-project-id" | \
  gcloud secrets create gcp-project-id \
    --data-file=- \
    --replication-policy="automatic"

echo -n "your_dataset_name" | \
  gcloud secrets create bq-dataset-my-pipeline \
    --data-file=- \
    --replication-policy="automatic"
```

---

## 6. Deploy the Cloud Run Job

Fill in the `cloud-run-job.yml` from the analyst's repo and deploy:

```bash
gcloud run jobs replace cloud-run-job.yml --region europe-west2
```

Test it with a manual run:

```bash
gcloud run jobs execute my-pipeline --region europe-west2 --wait
```

---

## 7. Schedule the job with Cloud Scheduler

```bash
gcloud scheduler jobs create http my-pipeline-schedule \
  --location=europe-west2 \
  --schedule="0 6 * * 1-5" \
  --uri="https://europe-west2-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/my-pipeline:run" \
  --message-body="{}" \
  --oauth-service-account-email=${PIPELINE_SA} \
  --description="Run my-pipeline weekdays at 06:00"
```

Cron schedule format: `minute hour day month weekday`
- `0 6 * * 1-5` — 06:00 Monday to Friday
- `0 8 * * 1` — 08:00 every Monday
- `0 */4 * * *` — every 4 hours

---

## 8. Set up branch protection on GitHub

In the analyst's pipeline repo, go to **Settings > Branches > Add rule**:

| Setting | Value |
|---|---|
| Branch name pattern | `main` |
| Require a pull request before merging | On |
| Required approvals | 1 |
| Require status checks to pass | On |
| Required status checks | `pytest`, `testthat` |
| Restrict pushes that create files | Off |
| Do not allow bypassing the above settings | On |

This ensures no code reaches production without tests passing and a peer review.
