# tests/testthat/test_pipeline.R
#
# Unit tests for R functions in this pipeline.
# Run with: Rscript -e "testthat::test_dir('tests/testthat')"
#
# These tests cover pure logic only — no GCP connections.
# Functions that call bigrquery or googleCloudStorageR should be tested
# with mocked responses or in a separate integration test suite.

library(testthat)


# ---------------------------------------------------------------------------
# Example: testing a data cleaning function
# ---------------------------------------------------------------------------

clean_column_names <- function(df) {
  names(df) <- tolower(gsub("[^a-zA-Z0-9]", "_", names(df)))
  df
}

test_that("clean_column_names lowercases names", {
  df <- data.frame(MyColumn = 1, AnotherCol = 2)
  result <- clean_column_names(df)
  expect_equal(names(result), c("mycolumn", "anothercol"))
})

test_that("clean_column_names replaces spaces with underscores", {
  df <- data.frame(check.names = FALSE, "My Column" = 1)
  result <- clean_column_names(df)
  expect_equal(names(result), "my_column")
})

test_that("clean_column_names does not alter row count", {
  df <- data.frame(A = 1:5, B = 6:10)
  result <- clean_column_names(df)
  expect_equal(nrow(result), 5)
})
