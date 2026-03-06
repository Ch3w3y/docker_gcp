# tests/testthat/test-extract.R
#
# Unit tests for validate_extract() and the AMR_ORGANISMS/AMR_COUNTRIES constants.
#
# Note: fetch_isolates() itself is NOT tested here — it requires a live
# BigQuery connection and is an integration concern. We test the validation
# logic separately using synthetic data.

# ---- Constants ----

test_that("AMR_ORGANISMS contains exactly 5 organisms", {
  expect_length(AMR_ORGANISMS, 5)
})

test_that("AMR_COUNTRIES contains exactly 5 countries", {
  expect_length(AMR_COUNTRIES, 5)
})

test_that("AMR_ORGANISMS has correct organism codes as names", {
  expected_codes <- c("ECOLI", "KPNEU", "SAUR", "PAER", "ABAUM")
  expect_equal(sort(names(AMR_ORGANISMS)), sort(expected_codes))
})

test_that("AMR_COUNTRIES has correct ISO codes as names", {
  expected_codes <- c("GB", "DE", "FR", "IT", "ES")
  expect_equal(sort(names(AMR_COUNTRIES)), sort(expected_codes))
})


# ---- validate_extract() ----

test_that("validate_extract passes on a well-formed data frame", {
  df <- make_test_isolates(n_per_group = 10)
  expect_invisible(validate_extract(df))
})

test_that("validate_extract errors on empty data frame", {
  df <- make_test_isolates(n_per_group = 10)[0, ]  # zero rows
  expect_error(validate_extract(df), regexp = "no rows")
})

test_that("validate_extract errors on missing required columns", {
  df <- make_test_isolates(n_per_group = 5) |>
    dplyr::select(-isolate_id)
  expect_error(validate_extract(df), regexp = "isolate_id")
})

test_that("validate_extract warns when an organism is missing from the data", {
  df <- make_test_isolates(n_per_group = 5) |>
    dplyr::filter(.data$organism_code != "ABAUM")
  expect_warning(validate_extract(df), regexp = "ABAUM")
})

test_that("validate_extract warns when a country is missing from the data", {
  df <- make_test_isolates(n_per_group = 5) |>
    dplyr::filter(.data$country_code != "ES")
  expect_warning(validate_extract(df), regexp = "ES")
})

test_that("validate_extract warns when is_resistant has NA values", {
  df <- make_test_isolates(n_per_group = 10)
  df$is_resistant[1:5] <- NA
  expect_warning(validate_extract(df), regexp = "NA")
})

test_that("validate_extract returns df invisibly on success", {
  df <- make_test_isolates(n_per_group = 10)
  result <- validate_extract(df)
  expect_equal(result, df)
})
