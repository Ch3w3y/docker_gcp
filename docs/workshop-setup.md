# Workshop: Building a Secure Cloud RAP

This guide is for the "R to the Cloud" hands-on workshop. It takes you through building a reproducible analytical pipeline, starting from local development and moving to a secure, pseudonymised deployment in Google Cloud Platform.

---

## 1. Prerequisites

Ensure you have the following ready before starting the exercises:
- **WSL2 & Docker Desktop:** Installed and running.
- **GCP Project:** Access to a project where you have the `Editor` role.
- **gcloud CLI:** Installed and authenticated (`gcloud auth login`).

---

## 2. Infrastructure Setup (Automated)

We have provided a script to set up all the "dummy" resources needed for this workshop. This avoids interfering with your production datasets.

```bash
# Navigate to the repo root
cd ~/projects/docker_gcp

# Run the workshop setup script
bash infra/setup-workshop-resources.sh
```

**This script will create:**
1. **BigQuery Dataset:** `workshop_surveillance`
2. **GCS Bucket:** `workshop-data-[project-id]`
3. **Secret Manager Entry:** `PIPELINE_SALT` (containing a dummy salt key)
4. **Service Account:** `workshop-analyst-sa` with minimal permissions.

---

## 3. Exercise: Pseudonymisation

In this exercise, we will modify the `example-pipeline` to ensure that patient IDs are never stored in plain text.

### Task 1: Update your `.env`
1. Copy `.env.example` to `.env`.
2. Set `PIPELINE_SALT` to a random string (e.g., `my_secret_workshop_salt`).
3. Set `GCP_PROJECT_ID` and other bucket/dataset names from the output of the setup script.

### Task 2: Implement the Hash in R
Open `example-pipeline/src/extract.R` and ensure the pseudonymisation step is active:

```r
# Retrieve salt from environment
salt <- Sys.getenv("PIPELINE_SALT")

# Hash the patient ID using SHA-256
isolates_raw$pseudo_id <- sapply(isolates_raw$patient_id, function(id) {
  digest::digest(paste0(id, salt), algo = "sha256", serialize = FALSE)
})

# Drop identifiable data immediately
isolates_raw$patient_id <- NULL
```

---

## 4. Exercise: Deploying to Cloud Run

Once your code is pseudonymising data locally, we will deploy it to the cloud.

### Task 1: Build and Push the Image
```bash
# Build the gcp-etl image
docker build -t europe-west2-docker.pkg.dev/[PROJECT]/docker-images/gcp-etl:latest gcp-etl/

# Push to Artifact Registry
docker push europe-west2-docker.pkg.dev/[PROJECT]/docker-images/gcp-etl:latest
```

### Task 2: Execute the Job
Deploy the Cloud Run Job using `cloud-run-job.yml` (update the placeholders first) and run it:

```bash
gcloud run jobs replace cloud-run-job.yml --region europe-west2
gcloud run jobs execute amr-pipeline --region europe-west2 --wait
```

---

## 5. Summary & Discussion

- **Where is the data?** It never left the secure cloud environment.
- **Where is the identifiable data?** It was dropped in memory during the `Extract` step.
- **Who can see the results?** Only those with access to the output GCS bucket.

This workflow fulfills the requirements for a **Reproducible Analytical Pipeline (RAP)** while maintaining the highest standards of data security and governance.
