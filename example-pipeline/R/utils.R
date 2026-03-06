# R/utils.R
#
# Shared helper functions used across the pipeline.
# These are internal (not exported) — they are used by other functions
# in the package but not called directly by users.

#' Build a fully-qualified BigQuery table identifier
#'
#' Returns the backtick-quoted `project.dataset.table` string used in
#' BigQuery SQL, safe for use with [glue::glue()].
#'
#' @param project GCP project ID.
#' @param dataset BigQuery dataset name.
#' @param table BigQuery table name.
#' @return A character string: `` `project.dataset.table` ``.
#'
#' @examples
#' bq_table_id("my-project", "my_dataset", "my_table")
#' # [1] "`my-project.my_dataset.my_table`"
#'
#' @noRd
bq_table_id <- function(project, dataset, table) {
  sprintf("`%s.%s.%s`", project, dataset, table)
}


#' Validate that a data frame has all required columns
#'
#' Stops with an informative error if any expected column is missing.
#' Use this at the start of transform functions to fail early with a
#' clear message rather than a cryptic error later.
#'
#' @param df A data frame to validate.
#' @param required_cols Character vector of column names that must be present.
#' @param context A short description of where this is called from,
#'   used in the error message. E.g. `"clean_referrals input"`.
#' @return `df`, invisibly, if validation passes.
#'
#' @examples
#' df <- data.frame(a = 1, b = 2)
#' validate_columns(df, c("a", "b"))     # passes silently
#' # validate_columns(df, c("a", "c"))  # would error: missing column 'c'
#'
#' @noRd
validate_columns <- function(df, required_cols, context = "input") {
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(
      "Missing required columns in ", context, ": ",
      paste(missing_cols, collapse = ", "),
      "\nActual columns: ", paste(names(df), collapse = ", "),
      call. = FALSE
    )
  }
  invisible(df)
}


#' Log a message with a timestamp
#'
#' Writes a timestamped message to stderr. This appears in Cloud Run logs
#' alongside the R output and helps trace timing across pipeline steps.
#'
#' @param ... Arguments passed to [paste()].
#' @return Invisibly returns `NULL`.
#'
#' @noRd
log_message <- function(...) {
  ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  message("[", ts, "] ", paste(...))
  invisible(NULL)
}
