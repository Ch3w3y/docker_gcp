# tests/testthat/setup.R
#
# Shared test fixtures and helper functions.
# This file is sourced automatically before all tests in the directory.

library(testthat)
library(dplyr)
library(lubridate)

# Source the package functions (in a real package, devtools::load_all() does this)
source("/workspace/R/utils.R")
source("/workspace/R/extract.R")
source("/workspace/R/transform.R")
source("/workspace/R/load.R")

# ---- Shared test data ----

# A minimal data frame representing one month of data for two organisms
# and two countries. Used as input to transform functions in multiple tests.
make_test_isolates <- function(
    n_per_group = 20,
    months      = 3,
    resistant_fraction = 0.3
) {
  set.seed(42)  # reproducible random numbers

  organisms <- c("ECOLI", "KPNEU", "SAUR")
  countries <- c("GB", "DE", "FR")

  start_month <- lubridate::floor_date(Sys.Date() - months * 30, "month")
  month_seq   <- seq(start_month, by = "month", length.out = months)

  expand.grid(
    organism_code = organisms,
    country_code  = countries,
    year_month    = month_seq,
    stringsAsFactors = FALSE
  ) |>
    tibble::as_tibble() |>
    dplyr::slice(rep(dplyr::row_number(), n_per_group)) |>
    dplyr::mutate(
      isolate_id   = paste0("ISO-", seq_len(dplyr::n())),
      sample_date  = as.Date(.data$year_month) + sample(0:27, dplyr::n(), replace = TRUE),
      antibiotic   = "AMOXICILLIN",
      is_resistant = sample(
        c(TRUE, FALSE),
        dplyr::n(),
        replace = TRUE,
        prob = c(resistant_fraction, 1 - resistant_fraction)
      )
    )
}

# A small clean dataset — passes validate_columns, has year_month
make_clean_isolates <- function(...) {
  make_test_isolates(...) |>
    dplyr::mutate(year_month = lubridate::floor_date(.data$sample_date, "month"))
}

# A minimal resistance rates data frame for testing load/pivot functions
make_test_rates <- function() {
  tibble::tibble(
    year_month    = rep(as.Date(c("2024-01-01", "2024-02-01")), each = 4),
    organism_code = rep(c("ECOLI", "ECOLI", "KPNEU", "KPNEU"), 2),
    country_code  = rep(c("GB", "DE"), 4),
    n_tested      = c(50, 45, 30, 35, 55, 40, 25, 30),
    n_resistant   = c(20, 18, 15, 14, 22, 16, 10, 12),
    pct_resistant = round(c(20, 18, 15, 14, 22, 16, 10, 12) /
                            c(50, 45, 30, 35, 55, 40, 25, 30) * 100, 1),
    low_count     = FALSE
  )
}
