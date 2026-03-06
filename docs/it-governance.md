# The Business Case for Modern Analytical Pipelines

Moving from local "laptop-based" analysis to Reproducible Analytical Pipelines (RAP) in the cloud is not just a technical upgrade—it is a significant improvement in **clinical/statistical governance, auditability, and service continuity.**

This page provides a framework and template for discussing these changes with IT, Security, and Information Governance (IG) departments.

---

## Why the "Laptop & Shared Drive" Model is a Risk

The traditional workflow (On-prem SQL -> Local R Notebook -> PDF Output) carries several hidden risks that modern RAPs mitigate:

| Risk | Local/Manual Workflow | RAP in the Cloud |
|---|---|---|
| **Auditability** | Changes to scripts are often un-tracked or saved as `analysis_v2_final_FINAL.R`. | Every single change is timestamped, attributed, and peer-reviewed in **Git**. |
| **Service Continuity** | If an analyst's laptop breaks or they leave the organisation, the process is often lost. | The pipeline is a **Docker container** that runs independently of any specific person's hardware. |
| **Data Security** | Sensitive data is often extracted to local `C:` drives or un-encrypted shared folders. | Data stays within **encrypted Cloud Storage** or BigQuery; access is controlled via IAM roles. |
| **Scalability** | Large datasets (millions of rows) frequently crash R sessions or exceed laptop RAM. | Cloud-native tools (BigQuery/Cloud Run) scale elastically to handle **billions of rows** without failure. |

---

## Technical Justification Template

*You can use the following text in an IT Request or Business Case document.*

### Objective
To implement a Reproducible Analytical Pipeline (RAP) framework for [Project Name]. This will transition our current manual analysis process to an automated, containerised workflow hosted on [Organisation]'s Google Cloud Platform (GCP) environment.

### Proposed Stack
- **Version Control:** GitHub/GitLab (Internal or Enterprise) for code provenance and peer review.
- **Environment Management:** Docker (WSL2) to ensure the analysis environment is identical during development and production.
- **Compute:** GCP Cloud Run (Serverless) to run jobs only when needed, reducing costs and removing dependency on local hardware.
- **Secrets Management:** GCP Secret Manager to remove hardcoded credentials from scripts.

### Governance & Security Benefits
1. **Peer Review by Default:** No code reaches production without a Pull Request (PR). This ensures that methodology is checked by at least two analysts, reducing the risk of statistical error in public-facing reports.
2. **Automated Testing:** We will implement "Validation Gates" (unit tests) that automatically check data quality before a report is generated.
3. **Environment Parity:** By using Docker, we eliminate the "works on my machine" problem. The code that produces the final PDF is guaranteed to be running the exact same package versions as the code used during development.
4. **Least Privilege Access:** The pipeline runs under a dedicated Service Account with "Read-Only" access to source data, following the principle of least privilege.

---

## Navigating the "Docker/WSL2" Request

IT departments are often hesitant to enable WSL2 (Windows Subsystem for Linux) or Docker on corporate laptops. When requesting access:

- **Frame it as "Standardisation":** Explain that Docker is the industry standard for reproducible research and is required to meet modern Open Data and RAP standards.
- **Address Security:** Note that Docker containers are isolated environments. They do not grant the analyst "Admin" rights over the Windows host machine; they provide a sandbox for the code to run in.
- **Reference the Cloud:** Explain that the final production environment *is* a container. To ensure the results are valid, the analyst *must* be able to test that same container locally.
