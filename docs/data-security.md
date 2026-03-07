# Data Security for Cloud Pipelines

Moving to cloud-hosted analytical pipelines changes how sensitive data is handled and protected. This page explains the security model — how data is accessed using credentials that never appear in code, what controls replace local file permissions, and how to handle datasets containing personal or special category data.

---

## 1. The Transition from On-Prem to Cloud

Most analysts are used to a model where data is "pulled" from an on-premise SQL server via a local connection. In the Cloud RAP model, data is "shared" between secure environments.

| Transition | Traditional Local Model | Modern RAP (GCP) Model |
|---|---|---|
| **Data Source** | On-premise SQL Server. | BigQuery or Cloud Storage (GCS). |
| **Authentication** | Username/Password in a script or stored locally. | **Application Default Credentials (ADC)** — no keys in code. |
| **Access Control** | Database-level permissions on the on-prem server. | **Identity & Access Management (IAM)** — roles tied to specific cloud services. |
| **Data in Transit** | Often unencrypted or via local VPN. | **TLS/SSL Encryption** is mandatory and automatic for all GCP services. |

---

## 2. Managing Sensitive Data

!!! important "UK GDPR terminology"
    This guide uses UK GDPR terminology. "Special category data" covers health records,
    ethnicity, biometrics, and other sensitive personal data (Article 9, UK GDPR). Some
    organisations use the US term "PHI" (Protected Health Information) — these refer to
    overlapping but distinct regulatory frameworks. If in doubt, consult your organisation's
    Data Protection Officer.

Public sector datasets often contain personal data or special category data — the term used in UK GDPR for sensitive information such as health records, ethnicity, or biometric data (Article 9, UK GDPR). Your RAP strategy must account for this:

### The "De-identification First" Principle
Whenever possible, your pipeline should ingest **de-identified or pseudonymised data**. If your analysis does not require a patient's Name or Date of Birth (DoB) to be used, they should not be included in the dataset that is uploaded to the cloud.

### 2.1. Pseudonymisation
Pseudonymisation replaces identifiable fields (like an NHS Number or Case ID) with a unique, non-identifiable reference. This allows you to link records (e.g., longitudinal analysis) without seeing the original ID.

| Technique | How it works | When to use |
|---|---|---|
| **Salted Hashing (SHA-256)** | Converts an ID into a long string of random characters using a secret "salt" key. | **Best practice.** Same ID + Same Salt = Same Hash. This allows for record-linking across datasets. |
| **Mapping Tables** | A secure "look-up" table that maps real IDs to random integers (e.g., 1001, 1002). | Use when you need simple, human-readable IDs for debugging or small cohorts. |
| **K-Anonymity** | Suppresses or aggregates groups with fewer than X individuals (e.g., 5 or 10). | Use for public-facing reports to prevent "re-identification" of rare cases. |

!!! tip "Never store the 'Salt' in your code"
    If you use salted hashing, store the "Salt" as a **GCP Secret**. This ensures that even if someone steals your code, they cannot reverse-engineer the original IDs without the secret key.

### Using Google Cloud Storage (GCS) Safely
Think of a GCS bucket as an "Encrypted Shared Drive." To keep it secure:
- **Never make a bucket public.** All buckets should be private by default.
- **Use Uniform Bucket-Level Access.** This ensures that permissions are managed centrally via IAM, not on individual files.
- **Grant Permissions to the Job, not the Analyst.** The Analyst may only need "Viewer" access to the data, while the Cloud Run Job has "Admin" access to process it.

---

## 3. Least Privilege via IAM Roles

In GCP, you grant permissions to a **Service Account** (the identity of the pipeline) rather than a person. This follows the principle of **Least Privilege**.

For a typical analytical pipeline, the Service Account only needs:
- `roles/storage.objectViewer` on the Input Data bucket.
- `roles/bigquery.dataViewer` on the source dataset.
- `roles/storage.objectAdmin` on the **Output** bucket (to write the final PDF/CSV).

---

## 4. Secrets are for Settings, Not Data

A common mistake is to hardcode BigQuery table names or bucket names in scripts. Instead, use **GCP Secret Manager** and environment variables.

### Local `.env` Example:
```bash
GCP_PROJECT_ID="your-project-id"
INPUT_DATA_BUCKET="raw-isolates-internal"
OUTPUT_REPORTS_BUCKET="amr-reports-public"
```

In your R or Python code:
```r
# R: Read from environment variable
bucket <- Sys.getenv("INPUT_DATA_BUCKET")
```

This ensures that even if your code is exposed on GitHub, **none of your sensitive data or infrastructure configuration is visible.**

---

## 5. Security & Auditability

By moving to this model, every access to the data is **logged**. If someone tries to access a sensitive table in BigQuery, the **Cloud Audit Logs** will record:
- Who made the request.
- From where.
- When.
- Exactly what data they accessed.

This provides a level of security and auditability that is almost impossible to achieve with manual extracts on local laptops.
