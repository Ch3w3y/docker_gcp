# tests/testthat/test-transform.R
#
# Unit tests for the transform functions: clean_isolates(),
# calculate_resistance_rates(), flag_threshold_breaches(), pivot_to_wide().
#
# Test naming convention: test_that("<function> <condition> <expected outcome>")
# Each test should test ONE thing. If a test fails, the name should tell you
# exactly what broke without needing to read the body.

# ---- clean_isolates() ----

test_that("clean_isolates removes rows where is_resistant is NA", {
  df <- make_test_isolates(n_per_group = 5)
  df$is_resistant[1:3] <- NA

  result <- clean_isolates(df)
  expect_false(any(is.na(result$is_resistant)))
})

test_that("clean_isolates adds year_month column", {
  df <- make_test_isolates(n_per_group = 10)
  result <- clean_isolates(df)
  expect_true("year_month" %in% names(result))
})

test_that("clean_isolates year_month is always the first day of the month", {
  df <- make_test_isolates(n_per_group = 10)
  result <- clean_isolates(df)
  expect_true(all(lubridate::day(result$year_month) == 1))
})

test_that("clean_isolates removes duplicate isolate_ids", {
  df <- make_test_isolates(n_per_group = 5)
  # Introduce a duplicate
  df_dup <- dplyr::bind_rows(df, df[1, ])
  result <- clean_isolates(df_dup)
  expect_equal(dplyr::n_distinct(result$isolate_id), nrow(result))
})

test_that("clean_isolates restricts to known organisms", {
  df <- make_test_isolates(n_per_group = 5)
  df$organism_code[1] <- "UNKNOWN_ORG"
  result <- clean_isolates(df)
  expect_false("UNKNOWN_ORG" %in% result$organism_code)
})

test_that("clean_isolates restricts to known countries", {
  df <- make_test_isolates(n_per_group = 5)
  df$country_code[1] <- "XX"
  result <- clean_isolates(df)
  expect_false("XX" %in% result$country_code)
})

test_that("clean_isolates returns a data frame", {
  df <- make_test_isolates(n_per_group = 5)
  result <- clean_isolates(df)
  expect_s3_class(result, "data.frame")
})

test_that("clean_isolates errors on missing required columns", {
  df <- make_test_isolates(n_per_group = 5) |>
    dplyr::select(-is_resistant)
  expect_error(clean_isolates(df), regexp = "is_resistant")
})


# ---- calculate_resistance_rates() ----

test_that("calculate_resistance_rates returns one row per organism-country-month", {
  df <- make_clean_isolates(n_per_group = 20, months = 3)
  result <- calculate_resistance_rates(df)

  # Result should have n_organisms * n_countries * n_months rows
  expected_rows <- dplyr::n_distinct(df$organism_code) *
    dplyr::n_distinct(df$country_code) *
    dplyr::n_distinct(df$year_month)
  expect_equal(nrow(result), expected_rows)
})

test_that("calculate_resistance_rates pct_resistant is between 0 and 100", {
  df <- make_clean_isolates(n_per_group = 20)
  result <- calculate_resistance_rates(df)
  expect_true(all(result$pct_resistant >= 0))
  expect_true(all(result$pct_resistant <= 100))
})

test_that("calculate_resistance_rates n_resistant <= n_tested", {
  df <- make_clean_isolates(n_per_group = 20)
  result <- calculate_resistance_rates(df)
  expect_true(all(result$n_resistant <= result$n_tested))
})

test_that("calculate_resistance_rates flags low_count groups correctly", {
  df <- make_clean_isolates(n_per_group = 5)  # 5 per group — below default min of 10
  result <- calculate_resistance_rates(df, min_isolates = 10)
  expect_true(all(result$low_count))
})

test_that("calculate_resistance_rates does not flag high_count groups", {
  df <- make_clean_isolates(n_per_group = 50)
  result <- calculate_resistance_rates(df, min_isolates = 10)
  expect_false(any(result$low_count))
})

test_that("calculate_resistance_rates handles all-resistant input", {
  df <- make_clean_isolates(n_per_group = 20, resistant_fraction = 1.0)
  result <- calculate_resistance_rates(df)
  expect_true(all(result$pct_resistant == 100))
})

test_that("calculate_resistance_rates handles all-susceptible input", {
  df <- make_clean_isolates(n_per_group = 20, resistant_fraction = 0.0)
  result <- calculate_resistance_rates(df)
  expect_true(all(result$pct_resistant == 0))
})

test_that("calculate_resistance_rates errors on missing required columns", {
  df <- make_clean_isolates() |> dplyr::select(-is_resistant)
  expect_error(calculate_resistance_rates(df), regexp = "is_resistant")
})


# ---- flag_threshold_breaches() ----

test_that("flag_threshold_breaches adds a breach column", {
  df <- make_test_rates()
  result <- flag_threshold_breaches(df, threshold = 30)
  expect_true("breach" %in% names(result))
})

test_that("flag_threshold_breaches breach is TRUE when pct_resistant exceeds threshold", {
  df <- tibble::tibble(pct_resistant = 60, low_count = FALSE)
  result <- flag_threshold_breaches(df, threshold = 50)
  expect_true(result$breach)
})

test_that("flag_threshold_breaches breach is FALSE when pct_resistant is below threshold", {
  df <- tibble::tibble(pct_resistant = 40, low_count = FALSE)
  result <- flag_threshold_breaches(df, threshold = 50)
  expect_false(result$breach)
})

test_that("flag_threshold_breaches breach is FALSE for low_count groups even if high rate", {
  df <- tibble::tibble(pct_resistant = 90, low_count = TRUE)
  result <- flag_threshold_breaches(df, threshold = 50)
  expect_false(result$breach)
})

test_that("flag_threshold_breaches breach is logical type", {
  df <- make_test_rates()
  result <- flag_threshold_breaches(df)
  expect_type(result$breach, "logical")
})


# ---- pivot_to_wide() ----

test_that("pivot_to_wide produces one row per organism-country pair", {
  df <- make_test_rates()
  result <- pivot_to_wide(df)
  # 2 organisms x 2 countries = 4 rows
  expect_equal(nrow(result), 4)
})

test_that("pivot_to_wide has one column per month", {
  df <- make_test_rates()
  result <- pivot_to_wide(df)
  n_months <- dplyr::n_distinct(df$year_month)
  month_cols <- setdiff(names(result), c("organism_code", "country_code"))
  expect_equal(length(month_cols), n_months)
})
