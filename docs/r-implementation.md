# Implementation Examples in R

This page provides concrete examples of how to achieve **Pseudonymisation** and **Automated Reporting** within an R environment, either by using R libraries or by structuring the process in your Docker image.

---

## 1. Pseudonymisation in R

To pseudonymise sensitive IDs (like NHS Numbers or Case IDs) so they remain consistent for record-linking without being reversible, use the `digest` package for **Salted Hashing**.

### Why use Salted Hashing?
- **Consistency:** Same ID + Same Salt = Same Hash.
- **Security:** Without the "Salt" key, the hash is practically impossible to reverse.

### Implementation Snippet:
```r
library(digest)
library(dplyr)

# 1. Retrieve the 'SALT' from an environment variable (set via GCP Secret Manager)
salt <- Sys.getenv("PIPELINE_SALT")
if (nchar(salt) == 0) stop("PIPELINE_SALT environment variable is not set!")

# 2. Function to pseudonymise a vector of IDs
pseudonymise_id <- function(ids, salt) {
  # Concatenate the ID with the salt and hash it using SHA-256
  sapply(ids, function(id) {
    digest(paste0(id, salt), algo = "sha256", serialize = FALSE)
  })
}

# 3. Apply to your dataframe
df_clean <- df_raw %>%
  mutate(pseudo_id = pseudonymise_id(nhs_number, salt)) %>%
  select(-nhs_number) # Drop the original identifiable column immediately
```

!!! tip "Analytical Best Practice"
    Perform pseudonymisation as the **very first step** after extraction. This ensures that the rest of your pipeline (and any intermediate `/tmp` files) only contains non-identifiable data.

---

## 2. Automated Reporting (PDF/HTML)

Moving from a manual "knit" in RStudio to an automated pipeline requires using the `rmarkdown` or `quarto` packages via the command line.

### Option A: Using `rmarkdown` (Standard R)
Create a `.Rmd` template in your `src/` directory and render it in your `run.sh` script.

**`src/report.Rmd`**
```markdown
---
title: "AMR Monthly Surveillance Report"
output: pdf_document
---

# Summary
This month, we observed `r nrow(monthly_rates)` organism-country-month estimates...
```

**`src/generate_report.R` (Orchestration Script)**
```r
library(rmarkdown)

# Load the data processed in the previous step
monthly_rates <- readRDS("/tmp/amr_monthly_rates.rds")

# Render the PDF
render("/workspace/src/report.Rmd",
       output_file = "/tmp/surveillance_report.pdf",
       params = list(data = monthly_rates))
```

### Option B: Structuring in the Docker Image (The "Infrastructure" way)
To generate PDFs in a Docker container, you need a LaTeX engine. We include `rmarkdown` and `knitr` in the base image, but you may need to install a lightweight LaTeX distribution like `tinytex`.

**Adding to your `install_base_packages.R`:**
```r
pkgs <- c(
  "rmarkdown",
  "knitr",
  "tinytex",
  "digest" # For pseudonymisation
)

# Install LaTeX for PDF generation
if (!tinytex::is_tinytex()) {
  tinytex::install_tinytex()
}
```

---

## 3. Uploading Reports to GCS

Once your report is generated in `/tmp/surveillance_report.pdf`, use `googleCloudStorageR` to share it with stakeholders.

```r
library(googleCloudStorageR)

bucket <- Sys.getenv("OUTPUT_REPORTS_BUCKET")

# Upload the PDF to a secure GCS bucket
gcs_upload(file = "/tmp/surveillance_report.pdf",
           bucket = bucket,
           name = paste0("reports/AMR_Report_", Sys.Date(), ".pdf"))
```

By structuring your pipeline this way, the "Analyst" only has to push code to GitHub. The "System" takes care of the extraction, pseudonymisation, analysis, and delivery of the final report.
