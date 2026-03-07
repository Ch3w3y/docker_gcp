# Talking to IT and Governance Teams

Moving to cloud-hosted analytical pipelines usually requires approval from your IT department,
Information Governance (IG) team, or a Security review board. This page gives you the language
and context to make those conversations productive.

---

## What your IT team is typically worried about

IT departments are not trying to block progress — they are managing real risks that they are
accountable for. Understanding what those risks are helps you address them directly.

The three most common concerns when requesting WSL2, Docker, and GCP access are:

**"What is this software actually doing on our laptops?"**
WSL2 is a Microsoft-developed feature built into Windows 10/11, not third-party software. It runs
a Linux environment inside a lightweight virtual machine managed by Windows itself. Docker runs
application code inside isolated containers — it does not grant administrator rights over the
Windows host machine.

**"Is data leaving our network?"**
In the cloud RAP model, sensitive source data stays in GCP (BigQuery or Cloud Storage) — it does
not move to analyst laptops. What the pipeline code does is read from GCP, process in-memory inside
a container, and write results back to GCP. Your GCP environment's data residency can be locked to
a UK region (e.g. `europe-west2` for London).

**"Who is responsible if something goes wrong?"**
Git provides a complete, tamper-evident audit trail of every change to analytical code — who made
it, when, and what was approved before it reached production. This is a stronger accountability
record than any manual process.

---

## How the cloud RAP model compares to the current approach

| Risk | Local/Manual Workflow | RAP in the Cloud |
|---|---|---|
| **Auditability** | Changes to scripts are often un-tracked or saved as `analysis_v2_final_FINAL.R`. | Every single change is timestamped, attributed, and peer-reviewed in **Git**. |
| **Service Continuity** | If an analyst's laptop breaks or they leave the organisation, the process is often lost. | The pipeline is a **Docker container** that runs independently of any specific person's hardware. |
| **Data Security** | Sensitive data is often extracted to local `C:` drives or un-encrypted shared folders. | Data stays within **encrypted Cloud Storage** or BigQuery; access is controlled via IAM roles. |
| **Scalability** | Large datasets (millions of rows) frequently crash R sessions or exceed laptop RAM. | Cloud-native tools (BigQuery/Cloud Run) scale elastically to handle **billions of rows** without failure. |

---

## Talking about WSL2 and Docker

When requesting WSL2 and Docker access from your IT team, frame the request around these points:

**Standardisation, not experimentation.** Docker is the industry standard for reproducible
research environments. The UK Government Analysis Function's RAP guidance and the NHS England
Reproducible Analytical Pipelines programme both reference containerisation. This is not a
novel request — it is alignment with established public sector data science practice.

**Containers are sandboxed.** A Docker container is an isolated environment for running code.
It does not have access to the host machine's file system beyond what is explicitly mounted.
It does not escalate privileges. If an analyst's container misbehaves, it can be stopped
instantly and leaves no lasting effect on the laptop.

**Local testing matches production.** The final production environment is a container running
on GCP. For the analyst's test results to be valid, they must be able to run that same
container locally. This is not optional — it is what makes "it passed tests" meaningful.

---

## Talking about data security

Key points for IG or data governance conversations:

**No credentials in code.** The pipeline never contains passwords, API keys, or connection
strings. All sensitive configuration is loaded from environment variables — either from a local
`.env` file (never committed to Git) or from GCP Secret Manager in production.

**Least privilege by design.** The service account that runs the pipeline in Cloud Run has
read-only access to its source data and write access only to its designated output location.
It cannot access other projects, other buckets, or other datasets.

**Encryption everywhere.** All data in GCP is encrypted at rest (AES-256) and in transit
(TLS) by default — this is not a configuration option, it is a platform guarantee.

**Audit trail.** Every change to pipeline code goes through a pull request, which requires
at least one reviewer's approval before merging. Git records every change permanently with
the author's identity and timestamp. This satisfies typical audit and change management
requirements.

---

## A template for an IT access request

Here is a worked example of how to frame a WSL2 and Docker access request. Adapt it to your
organisation's terminology and request process:

---

*We are requesting access to enable **Windows Subsystem for Linux 2 (WSL2)** and **Docker Desktop**
on analyst laptops for the purpose of developing and testing Reproducible Analytical Pipelines (RAP).*

*WSL2 is a Microsoft-provided feature of Windows 10/11 (not third-party software) that runs a
Linux environment in a managed virtual machine. Docker Desktop uses WSL2 to run application code
in isolated containers.*

*This access is required because our production pipeline runs inside a Docker container on
Google Cloud Platform. To ensure test results are valid and that "works locally" is meaningful,
analysts must be able to run the same container locally during development.*

*The following security controls are in place:*
- *No sensitive data is stored on analyst laptops — all data remains in GCP (BigQuery / Cloud Storage)*
- *No credentials appear in code — all configuration is loaded from environment variables or GCP Secret Manager*
- *All code changes go through peer review (GitHub pull request) before reaching production*
- *The pipeline service account follows least-privilege IAM principles*

---

## Questions your IG team may ask

**"Can patient data leave the GCP environment?"**
No. The pipeline reads from BigQuery or GCS, processes in-memory, and writes back to GCP.
Analyst laptops only run the pipeline against synthetic test data during local development.

**"How do we know who made a change to the pipeline?"**
Every commit to Git is permanently attributed to the committing analyst's GitHub account, with
a timestamp. Every change that reached production went through a pull request with a named reviewer.

**"What if an analyst leaves the organisation?"**
Their GitHub access is revoked. The pipeline code remains in the repository — accessible,
documented, and runnable by any other team member. There is no dependency on any individual's
laptop or local environment.

**"How do we audit what the pipeline did?"**
Cloud Logging captures the full output of every Cloud Run Job execution, including timestamps,
exit status, and all messages printed by the pipeline. These logs are retained and searchable.
