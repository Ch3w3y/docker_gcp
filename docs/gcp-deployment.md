# GCP Deployment Guide

This guide covers the one-time infrastructure setup required before analyst
pipeline repos can be deployed to Cloud Run. It is written for platform and
infrastructure engineers. Analysts do not need to follow these steps.

---

## Overview of the components

Before running commands, it helps to understand what each GCP service does and
why it is part of this architecture:

| Service | What it is | Why we use it |
|---|---|---|
| **Artifact Registry** | A private container image registry hosted in GCP | Stores the built `gcp-etl` and `gcp-app` images close to where they run |
| **Cloud Storage (GCS)** | Object storage — think a shared network drive | Stores synced pipeline code; mounted into containers at `/workspace` |
| **Cloud Run Jobs** | Serverless batch execution — runs a container, waits for it to finish, stops | Runs ETL pipelines on schedule without a persistent server to manage |
| **Cloud Scheduler** | A managed cron service | Triggers Cloud Run Jobs on a time-based schedule |
| **Secret Manager** | Encrypted storage for configuration values and credentials | Provides environment variables to Cloud Run without storing them in code |
| **IAM** | Identity and Access Management — controls who can do what | Ensures each pipeline only accesses the resources it needs |
| **Workload Identity Federation (WIF)** | Allows GitHub Actions to authenticate to GCP without a stored key | Avoids the security risk of long-lived credentials as GitHub secrets |

---

## Prerequisites

- A GCP project with billing enabled
- `gcloud` CLI installed and authenticated: `gcloud auth login`
- Owner or Editor role on the project (for initial setup)

Enable the required APIs:

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  cloudscheduler.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com
```

---

## 1. Create the Artifact Registry repository

Artifact Registry stores Docker images. Creating one repository to hold all
base images keeps things organised.

```bash
gcloud artifacts repositories create docker-images \
  --repository-format=docker \
  --location=europe-west2 \
  --description="Base images for Cloud Run pipelines"
```

Verify it was created:

```bash
gcloud artifacts repositories list --location=europe-west2
```

---

## 2. Create the GCS code bucket

This single bucket holds the synced code from every pipeline repo, with each
repo in its own subfolder. This is the bucket that Cloud Run Jobs mount at
`/workspace`.

```bash
gcloud storage buckets create gs://dept-pipeline-code \
  --location=europe-west2 \
  --uniform-bucket-level-access
```

After pipelines are deployed and synced, the bucket will look like this:

```
gs://dept-pipeline-code/
├── pipeline-a/
│   ├── run.sh
│   ├── src/
│   └── tests/
├── pipeline-b/
│   ├── run.sh
│   └── src/
```

**Note on bucket naming**: GCS bucket names are globally unique across all GCP
customers. If `dept-pipeline-code` is taken, add a project-specific suffix such
as `dept-pipeline-code-abc123`.

---

## 3. Set up the GitHub Actions service account

This service account is used by GitHub Actions to push images to Artifact
Registry and sync code to GCS. It requires only the minimum permissions for
those two tasks.

```bash
PROJECT_ID="your-project-id"
SA_NAME="github-actions"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create ${SA_NAME} \
  --project=${PROJECT_ID} \
  --display-name="GitHub Actions"

# Push images to Artifact Registry
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer"

# Sync code to the code bucket
gcloud storage buckets add-iam-policy-binding gs://dept-pipeline-code \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"
```

### Set up Workload Identity Federation

WIF lets GitHub Actions authenticate to GCP using short-lived tokens rather
than a stored service account key. This is the preferred approach — there is no
long-lived credential to rotate or accidentally expose.

How it works: GitHub's OIDC provider issues a token identifying the specific
repository and workflow. GCP verifies that token against a configured trust
relationship and exchanges it for a short-lived GCP access token. No keys are
stored anywhere.

```bash
REPO="Ch3w3y/docker_gcp"  # replace with each pipeline repo

# Create the identity pool (once per GCP project)
gcloud iam workload-identity-pools create "github" \
  --project=${PROJECT_ID} \
  --location="global" \
  --display-name="GitHub Actions"

# Create the OIDC provider (once per GCP project)
gcloud iam workload-identity-pools providers create-oidc "github" \
  --project=${PROJECT_ID} \
  --location="global" \
  --workload-identity-pool="github" \
  --display-name="GitHub" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Retrieve the pool resource name
POOL_ID=$(gcloud iam workload-identity-pools describe "github" \
  --project=${PROJECT_ID} \
  --location="global" \
  --format="value(name)")

# Allow the GitHub repo to impersonate the SA
gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --project=${PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/${REPO}"

# Output the values to store as GitHub secrets
echo "GCP_WORKLOAD_IDENTITY_PROVIDER: ${POOL_ID}/providers/github"
echo "GCP_SERVICE_ACCOUNT: ${SA_EMAIL}"
```

Repeat the `add-iam-policy-binding` command for each pipeline repo that needs
to push images or sync code. The pool and provider are created once and reused.

### Fallback: service account key

If WIF is not available, generate a key and base64-encode it for the GitHub
secret:

```bash
gcloud iam service-accounts keys create key.json \
  --iam-account=${SA_EMAIL}

base64 -w0 key.json  # copy this output as the GCP_SA_KEY secret
rm key.json           # do not leave key files on disk
```

---

## 4. Create a pipeline service account

Each pipeline runs as its own dedicated service account. This follows the
principle of least privilege — if one pipeline's credentials are compromised,
it cannot affect other pipelines or data it should not access.

```bash
PIPELINE_NAME="my-pipeline"
PIPELINE_SA="${PIPELINE_NAME}-sa@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create ${PIPELINE_NAME}-sa \
  --project=${PROJECT_ID} \
  --display-name="${PIPELINE_NAME} Cloud Run Job"
```

Grant the minimum permissions:

```bash
# Read pipeline code from the code bucket (required for GCS volume mount)
gcloud storage buckets add-iam-policy-binding gs://dept-pipeline-code \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/storage.objectViewer"

# Read BigQuery tables
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/bigquery.dataViewer"

# Run BigQuery queries
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/bigquery.jobUser"

# Read and write data in the pipeline's data bucket
gcloud storage buckets add-iam-policy-binding gs://your-data-bucket \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/storage.objectAdmin"

# Access secrets from Secret Manager
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${PIPELINE_SA}" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 5. Add secrets to Secret Manager

For each variable in the analyst's `.env.example`, create a corresponding
secret. The secret name must match the variable name referenced in
`cloud-run-job.yml`.

```bash
# Create each secret
echo -n "your-project-id" | \
  gcloud secrets create gcp-project-id \
    --data-file=- \
    --replication-policy="automatic"

echo -n "your_dataset_name" | \
  gcloud secrets create bq-dataset-my-pipeline \
    --data-file=- \
    --replication-policy="automatic"

echo -n "your-data-bucket" | \
  gcloud secrets create gcs-data-bucket-my-pipeline \
    --data-file=- \
    --replication-policy="automatic"
```

To update a secret value later:

```bash
echo -n "new-value" | \
  gcloud secrets versions add SECRET_NAME --data-file=-
```

Secret Manager retains all versions. The `cloud-run-job.yml` references
`key: latest` which always uses the most recent version.

---

## 6. Deploy the Cloud Run Job

Fill in all `UPPER_CASE` placeholders in the analyst's `cloud-run-job.yml`
and deploy:

```bash
gcloud run jobs replace cloud-run-job.yml --region europe-west2
```

Verify it was created:

```bash
gcloud run jobs list --region europe-west2
```

Test with a manual execution:

```bash
gcloud run jobs execute my-pipeline --region europe-west2 --wait
```

The `--wait` flag blocks until the job completes and shows the final status.
Without it, the command returns immediately and the job runs in the background.

---

## 7. Schedule the job

Cloud Scheduler calls the Cloud Run Jobs API on a cron schedule. The scheduler
job needs permission to invoke the Cloud Run job, which it does by acting as
the pipeline's service account.

```bash
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")

gcloud scheduler jobs create http ${PIPELINE_NAME}-schedule \
  --location=europe-west2 \
  --schedule="0 6 * * 1-5" \
  --uri="https://europe-west2-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${PROJECT_ID}/jobs/${PIPELINE_NAME}:run" \
  --message-body="{}" \
  --oauth-service-account-email=${PIPELINE_SA} \
  --description="Run ${PIPELINE_NAME} weekdays at 06:00"
```

Common cron schedules:

| Schedule | Meaning |
|---|---|
| `0 6 * * 1-5` | 06:00 Monday to Friday |
| `0 8 * * 1` | 08:00 every Monday |
| `0 */4 * * *` | Every 4 hours |
| `30 7 1 * *` | 07:30 on the first day of each month |
| `0 9 * * *` | 09:00 every day |

Use [crontab.guru](https://crontab.guru) to build and verify cron expressions.

To trigger the scheduler manually (useful for testing):

```bash
gcloud scheduler jobs run ${PIPELINE_NAME}-schedule --location=europe-west2
```

---

## 8. Set up branch protection

In each pipeline repo on GitHub, go to **Settings > Branches > Add rule**:

| Setting | Value |
|---|---|
| Branch name pattern | `main` |
| Require a pull request before merging | On |
| Required number of approvals | 1 |
| Require status checks to pass before merging | On |
| Required status checks | `pytest`, `testthat` |
| Do not allow bypassing the above settings | On |

This ensures that no code reaches the GCS bucket (and therefore production)
without tests passing and at least one peer review.

---

## Viewing job logs

Cloud Run Job output (stdout and stderr from your `run.sh` and scripts) is
captured automatically in Cloud Logging.

### In the Cloud Console

1. Navigate to **Cloud Run > Jobs**
2. Click the job name
3. Open the **Executions** tab
4. Click any execution to see its status and full log output

### Via gcloud

```bash
# View logs for the most recent executions
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="my-pipeline"' \
  --project=${PROJECT_ID} \
  --limit=100 \
  --order=desc \
  --format="table(timestamp, textPayload)"
```

---

## Updating a pipeline after deployment

When an analyst merges to main in their pipeline repo:

1. GitHub Actions runs `sync-to-gcs.yml` and copies the updated code to GCS
2. The Cloud Run Job picks up the new code automatically on its next execution
   — no redeployment needed

Only redeploy the Cloud Run Job (run `gcloud run jobs replace`) if:
- The `cloud-run-job.yml` spec itself changes (resources, schedule, env vars)
- The base image tag changes

---

## Monitoring and alerting

### Execution history

```bash
gcloud run jobs executions list --job=my-pipeline --region=europe-west2
```

### Set up failure alerts

Create a Cloud Monitoring alerting policy to notify on job failure:

```bash
# Create a notification channel (email example)
gcloud monitoring channels create \
  --display-name="Pipeline alerts" \
  --type=email \
  --channel-labels=email_address=your-team@organisation.gov.uk
```

Then in the Cloud Console: **Monitoring > Alerting > Create Policy**

- Resource type: Cloud Run Job
- Metric: `run.googleapis.com/job/completed_execution_count`
- Filter: `result != "succeeded"`
- Notification: the channel you just created

### Cost monitoring

Cloud Run Jobs bill only for the time the container is actually running. At
the time of writing, Cloud Run charges approximately $0.00002 per vCPU-second
and $0.0000025 per GiB-second of memory. A typical pipeline running for 10
minutes with 2 vCPUs and 2 GiB costs around $0.02–0.05 per execution.

Set up budget alerts in **Billing > Budgets & Alerts** to be notified if costs
exceed a threshold. For a department running dozens of pipelines, a monthly
budget alert at a modest threshold will catch runaway jobs early.

> **Further reading**: [Cloud Run pricing](https://cloud.google.com/run/pricing) | [Cloud Run Jobs documentation](https://cloud.google.com/run/docs/create-jobs)
