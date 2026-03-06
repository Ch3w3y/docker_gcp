# R/transform.R
#
# Pure transformation functions for AMR surveillance data.
#
# These functions take data frames as input and return data frames as output.
# They perform NO I/O — no BigQuery calls, no file reads or writes, no
# Sys.getenv() calls. This makes them easy to test with synthetic data.
#
# The pattern:
#   raw isolates  →  clean_isolates()  →  calculate_resistance_rates()
#                                       →  flag_threshold_breaches()


#' Clean raw AMR isolate records
#'
#' Applies data quality rules to the raw isolate data:
#'
#' 1. Removes rows where `is_resistant` is `NA`
#' 2. Coerces `sample_date` to `Date` if not already
#' 3. Adds a `year_month` column (first day of the sample month)
#' 4. Removes any duplicate `isolate_id` records (keeps first occurrence)
#' 5. Restricts to known organisms and countries
#'
#' @param df Data frame from [fetch_isolates()], validated by [validate_extract()].
#' @return A cleaned data frame with an additional `year_month` column.
#'
#' @export
clean_isolates <- function(df) {
  validate_columns(df, c(
    "isolate_id", "country_code", "organism_code",
    "sample_date", "is_resistant"
  ), context = "clean_isolates")

  n_start <- nrow(df)

  result <- df |>
    # Remove untestable records
    dplyr::filter(!is.na(.data$is_resistant)) |>
    # Normalise date column
    dplyr::mutate(
      sample_date = as.Date(.data$sample_date),
      year_month  = lubridate::floor_date(.data$sample_date, "month")
    ) |>
    # Remove duplicates (keep first occurrence by date)
    dplyr::arrange(.data$sample_date) |>
    dplyr::distinct(.data$isolate_id, .keep_all = TRUE) |>
    # Restrict to surveillance panel
    dplyr::filter(
      .data$organism_code %in% names(AMR_ORGANISMS),
      .data$country_code  %in% names(AMR_COUNTRIES)
    )

  n_removed <- n_start - nrow(result)
  if (n_removed > 0) {
    log_message("Removed ", n_removed, " rows during cleaning (",
                round(n_removed / n_start * 100, 1), "% of extract)")
  }

  result
}


#' Calculate monthly resistance rates by organism and country
#'
#' Aggregates cleaned isolate records to produce a monthly time series of
#' resistance rates. For each combination of organism, country, and month,
#' calculates:
#'
#' - `n_tested`: number of isolates tested
#' - `n_resistant`: number classified as resistant
#' - `pct_resistant`: percentage resistant (0–100), rounded to 1 decimal place
#'
#' Months with fewer than `min_isolates` tests are flagged with
#' `low_count = TRUE` and should be interpreted cautiously (small denominators
#' make rates unreliable).
#'
#' @param df Cleaned data frame from [clean_isolates()].
#' @param min_isolates Minimum number of isolates required for a reliable
#'   rate estimate. Groups below this threshold are flagged, not removed.
#'   Defaults to `10`.
#'
#' @return A data frame with one row per organism-country-month combination,
#'   with columns: `year_month`, `organism_code`, `country_code`, `n_tested`,
#'   `n_resistant`, `pct_resistant`, `low_count`.
#'
#' @export
calculate_resistance_rates <- function(df, min_isolates = 10) {
  validate_columns(df, c(
    "organism_code", "country_code", "year_month", "is_resistant"
  ), context = "calculate_resistance_rates")

  df |>
    dplyr::group_by(.data$year_month, .data$organism_code, .data$country_code) |>
    dplyr::summarise(
      n_tested    = dplyr::n(),
      n_resistant = sum(.data$is_resistant, na.rm = TRUE),
      .groups     = "drop"
    ) |>
    dplyr::mutate(
      pct_resistant = round(.data$n_resistant / .data$n_tested * 100, 1),
      low_count     = .data$n_tested < min_isolates
    ) |>
    dplyr::arrange(.data$year_month, .data$organism_code, .data$country_code)
}


#' Flag resistance rates that breach a defined threshold
#'
#' Adds a `breach` column to a resistance rates data frame. A breach occurs
#' when `pct_resistant` exceeds `threshold` AND `low_count` is `FALSE`
#' (i.e., the rate is based on sufficient data to be meaningful).
#'
#' This is used to identify high-resistance combinations for reporting.
#'
#' @param df Data frame from [calculate_resistance_rates()].
#' @param threshold Resistance percentage above which a breach is flagged.
#'   Defaults to `50` (i.e., majority resistance).
#'
#' @return `df` with an additional `breach` logical column.
#'
#' @export
flag_threshold_breaches <- function(df, threshold = 50) {
  validate_columns(df, c("pct_resistant", "low_count"),
                   context = "flag_threshold_breaches")

  df |>
    dplyr::mutate(
      breach = !.data$low_count & .data$pct_resistant >= threshold
    )
}


#' Produce a wide-format 12-month summary matrix
#'
#' Reshapes the monthly resistance rates into a wide format with one column
#' per month, suitable for export to a dashboard or report. Each row is
#' an organism-country pair; columns are the 12 months in the time series.
#'
#' @param df Data frame from [calculate_resistance_rates()].
#' @return A wide data frame with columns `organism_code`, `country_code`,
#'   and one column per distinct `year_month` value.
#'
#' @export
pivot_to_wide <- function(df) {
  validate_columns(df, c("organism_code", "country_code",
                          "year_month", "pct_resistant"),
                   context = "pivot_to_wide")

  df |>
    dplyr::select(
      .data$organism_code, .data$country_code,
      .data$year_month, .data$pct_resistant
    ) |>
    tidyr::pivot_wider(
      names_from  = .data$year_month,
      values_from = .data$pct_resistant
    )
}
