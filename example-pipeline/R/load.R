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


#' Generate and upload a resistance trend plot to GCS
#'
#' Produces a ggplot2 line chart of monthly resistance rates (one line per
#' country, faceted by organism), saves it as a PDF to `/tmp`, then uploads
#' it to the GCS bucket defined by `GCS_DATA_BUCKET`. The output path is
#' `{OUTPUT_PREFIX}/amr_resistance_trends.pdf` if `OUTPUT_PREFIX` is set,
#' or `amr_resistance_trends.pdf` at the bucket root if not.
#'
#' @param df Data frame from [calculate_resistance_rates()] — must contain
#'   `year_month`, `organism_code`, `country_code`, `pct_resistant`.
#' @param bucket GCS bucket name (no `gs://` prefix).
#' @param prefix Optional folder prefix, e.g. an attendee name. Defaults to
#'   `""` (root of bucket).
#'
#' @return Invisibly returns the GCS object path the file was uploaded to.
#'
#' @export
write_plot_to_gcs <- function(df, bucket, prefix = "") {
  validate_columns(df, c("year_month", "organism_code", "country_code",
                          "pct_resistant"),
                   context = "write_plot_to_gcs")

  object_name <- if (nzchar(prefix)) {
    paste0(prefix, "/amr_resistance_trends.pdf")
  } else {
    "amr_resistance_trends.pdf"
  }

  tmp <- tempfile(fileext = ".pdf")

  p <- ggplot2::ggplot(df,
         ggplot2::aes(
           x      = .data$year_month,
           y      = .data$pct_resistant,
           colour = .data$country_code,
           group  = .data$country_code
         )
       ) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_point(size = 1.5) +
    ggplot2::facet_wrap(~ organism_code, ncol = 2, scales = "free_y") +
    ggplot2::scale_y_continuous(limits = c(0, 100),
                                labels = function(x) paste0(x, "%")) +
    ggplot2::labs(
      title    = "AMR Resistance Rates by Organism and Country",
      subtitle = paste("Generated:", format(Sys.Date(), "%B %Y")),
      x        = NULL,
      y        = "% Resistant",
      colour   = "Country"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")

  ggplot2::ggsave(tmp, plot = p, width = 10, height = 8, device = "pdf")

  log_message("Uploading plot to gs://", bucket, "/", object_name)

  googleAuthR::gar_gce_auth()
  googleCloudStorageR::gcs_upload(
    file        = tmp,
    bucket      = bucket,
    name        = object_name,
    type        = "application/pdf"
  )

  log_message("Plot uploaded: gs://", bucket, "/", object_name)
  invisible(object_name)
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
