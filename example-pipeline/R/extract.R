# R/extract.R
#
# Functions for fetching AMR isolate records from BigQuery.
#
# These are the "extract" functions in the ETL pattern. They are the only
# functions in the package that perform I/O — everything else is pure.
#
# Note: bigrquery uses Application Default Credentials (ADC) automatically.
# Locally: run `gcloud auth application-default login` once.
# In Cloud Run: credentials come from the attached service account.

# The organisms and countries we track in this surveillance system.
# Defined here so they can be used in validation and as documentation.

#' Organisms included in the AMR surveillance panel
#'
#' A named character vector mapping short organism codes to display names.
#' Used for validation and labelling in outputs.
#'
#' @export
AMR_ORGANISMS <- c(
  "ECOLI"  = "Escherichia coli",
  "KPNEU"  = "Klebsiella pneumoniae",
  "SAUR"   = "Staphylococcus aureus (MRSA)",
  "PAER"   = "Pseudomonas aeruginosa",
  "ABAUM"  = "Acinetobacter baumannii"
)

#' Countries included in the AMR surveillance panel
#'
#' A named character vector mapping ISO 3166-1 alpha-2 country codes to
#' display names for the five countries included in this surveillance system.
#'
#' @export
AMR_COUNTRIES <- c(
  "GB" = "United Kingdom",
  "DE" = "Germany",
  "FR" = "France",
  "IT" = "Italy",
  "ES" = "Spain"
)


#' Fetch AMR isolate records from BigQuery
#'
#' Retrieves antimicrobial resistance testing records for the defined
#' surveillance organisms and countries. Returns one row per isolate test.
#'
#' The source table is expected to have the schema:
#' | Column | Type | Description |
#' |--------|------|-------------|
#' | `isolate_id` | STRING | Unique isolate identifier |
#' | `country_code` | STRING | ISO 3166-1 alpha-2 country code |
#' | `organism_code` | STRING | Organism code from [AMR_ORGANISMS] |
#' | `sample_date` | DATE | Date the sample was collected |
#' | `antibiotic` | STRING | Antibiotic tested |
#' | `is_resistant` | BOOL | Whether the isolate was resistant |
#'
#' @param project GCP project ID. Set via `GCP_PROJECT_ID` environment variable.
#' @param dataset BigQuery dataset name. Set via `BQ_DATASET`.
#' @param table Source table name. Defaults to `"amr_isolates"`.
#' @param months Number of months of data to fetch, counting back from today.
#'   Defaults to `12`.
#'
#' @return A data frame with columns: `isolate_id`, `country_code`,
#'   `organism_code`, `sample_date`, `antibiotic`, `is_resistant`.
#'
#' @examples
#' \dontrun{
#' isolates <- fetch_isolates(
#'   project = Sys.getenv("GCP_PROJECT_ID"),
#'   dataset = Sys.getenv("BQ_DATASET")
#' )
#' }
#'
#' @export
fetch_isolates <- function(project, dataset, table = "amr_isolates", months = 12) {
  cutoff_date <- lubridate::floor_date(Sys.Date() - months * 30, "month")

  organism_list <- paste0("'", names(AMR_ORGANISMS), "'", collapse = ", ")
  country_list  <- paste0("'", names(AMR_COUNTRIES), "'", collapse = ", ")

  sql <- glue::glue("
    SELECT
      isolate_id,
      country_code,
      organism_code,
      sample_date,
      antibiotic,
      is_resistant
    FROM {bq_table_id(project, dataset, table)}
    WHERE sample_date >= DATE('{cutoff_date}')
      AND organism_code IN ({organism_list})
      AND country_code IN ({country_list})
    ORDER BY sample_date, country_code, organism_code
  ")

  log_message("Fetching isolates from ", bq_table_id(project, dataset, table))
  log_message("Cutoff date: ", cutoff_date)

  con <- DBI::dbConnect(bigrquery::bigquery(), project = project)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  result <- DBI::dbGetQuery(con, sql)

  log_message("Fetched ", nrow(result), " isolate records")
  result
}


#' Validate the structure and content of extracted isolate data
#'
#' Checks that the data frame returned by [fetch_isolates()] has the expected
#' columns, no entirely-missing organisms or countries, and plausible values.
#' Stops with an informative error if any check fails.
#'
#' @param df Data frame returned by [fetch_isolates()].
#' @return `df` invisibly if all checks pass.
#'
#' @export
validate_extract <- function(df) {
  # Required columns
  validate_columns(df, c(
    "isolate_id", "country_code", "organism_code",
    "sample_date", "antibiotic", "is_resistant"
  ), context = "validate_extract")

  # Must have at least one row
  if (nrow(df) == 0) {
    stop("Extract returned no rows. Check the source table and date range.",
         call. = FALSE)
  }

  # Check that all expected organisms are present
  missing_orgs <- setdiff(names(AMR_ORGANISMS), unique(df$organism_code))
  if (length(missing_orgs) > 0) {
    warning(
      "Some expected organisms have no data in this period: ",
      paste(missing_orgs, collapse = ", ")
    )
  }

  # Check that all expected countries are present
  missing_countries <- setdiff(names(AMR_COUNTRIES), unique(df$country_code))
  if (length(missing_countries) > 0) {
    warning(
      "Some expected countries have no data in this period: ",
      paste(missing_countries, collapse = ", ")
    )
  }

  # is_resistant should be logical (TRUE/FALSE), not NA
  na_resistant <- sum(is.na(df$is_resistant))
  if (na_resistant > 0) {
    warning(na_resistant, " rows have NA for is_resistant and will be excluded.")
  }

  log_message("Extract validation passed: ",
              nrow(df), " rows, ",
              dplyr::n_distinct(df$organism_code), " organisms, ",
              dplyr::n_distinct(df$country_code), " countries")

  invisible(df)
}
