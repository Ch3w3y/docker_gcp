# R/load.R
#
# Functions for writing AMR surveillance results to BigQuery.
#
# These are the "load" functions in the ETL pattern. Like the extract
# functions, they perform I/O — they are intentionally thin wrappers
# around the pure transform functions, and are not directly unit-tested.
#
# The key design principle: these functions call the pure functions from
# transform.R. The business logic lives in transform.R and is tested there.


#' Write monthly AMR resistance rates to BigQuery
#'
#' Writes the output of [calculate_resistance_rates()] to a BigQuery table.
#' By default, replaces the contents of the output table on each run
#' (`WRITE_TRUNCATE`). This is appropriate for a monthly surveillance summary
#' that is fully regenerated from source data each run.
#'
#' @param df Data frame from [calculate_resistance_rates()] or
#'   [flag_threshold_breaches()].
#' @param project GCP project ID.
#' @param dataset BigQuery dataset name.
#' @param table Output table name. Defaults to `"amr_monthly_rates"`.
#' @param write_disposition One of `"WRITE_TRUNCATE"` (replace, default) or
#'   `"WRITE_APPEND"` (add rows).
#'
#' @return Invisibly returns the number of rows written.
#'
#' @examples
#' \dontrun{
#' write_amr_summary(
#'   df      = monthly_rates,
#'   project = Sys.getenv("GCP_PROJECT_ID"),
#'   dataset = Sys.getenv("BQ_DATASET")
#' )
#' }
#'
#' @export
write_amr_summary <- function(df,
                               project,
                               dataset,
                               table             = "amr_monthly_rates",
                               write_disposition = "WRITE_TRUNCATE") {
  validate_columns(df, c(
    "year_month", "organism_code", "country_code",
    "n_tested", "n_resistant", "pct_resistant"
  ), context = "write_amr_summary")

  target <- bigrquery::bq_table(project, dataset, table)

  log_message("Writing ", nrow(df), " rows to ", bq_table_id(project, dataset, table))
  log_message("Write disposition: ", write_disposition)

  bigrquery::bq_table_upload(
    x                 = target,
    values            = df,
    write_disposition = write_disposition
  )

  log_message("Write complete: ", nrow(df), " rows loaded")
  invisible(nrow(df))
}


#' Write the wide-format summary matrix to BigQuery
#'
#' Writes the output of [pivot_to_wide()] to a separate summary table.
#' This table is the primary input for dashboards — one row per
#' organism-country pair, with monthly columns.
#'
#' @param df Wide data frame from [pivot_to_wide()].
#' @param project GCP project ID.
#' @param dataset BigQuery dataset name.
#' @param table Output table name. Defaults to `"amr_monthly_matrix"`.
#'
#' @return Invisibly returns the number of rows written.
#'
#' @export
write_amr_matrix <- function(df, project, dataset, table = "amr_monthly_matrix") {
  target <- bigrquery::bq_table(project, dataset, table)

  log_message("Writing AMR matrix: ", nrow(df), " organism-country pairs")

  bigrquery::bq_table_upload(
    x                 = target,
    values            = df,
    write_disposition = "WRITE_TRUNCATE"
  )

  invisible(nrow(df))
}
