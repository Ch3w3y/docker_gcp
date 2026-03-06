# Writing and Running Tests

This guide explains how to write unit tests for pipeline code using pytest
(Python) and testthat (R), and how those tests fit into the broader workflow.

---

## Why we write tests

A pipeline that runs once and produces the right answer is easy to write. The
difficult part is keeping it correct over time as the data changes, as
colleagues add features, and as packages are updated.

Unit tests are automated checks that run every time a pull request is opened.
If a change breaks something, the tests catch it before the code reaches
production — before it runs against real data, before a report is wrong, before
a stakeholder notices.

More practically: tests are documentation you can run. A test named
`test_null_values_in_date_column_are_dropped` tells a future reader exactly
what the function is supposed to do with null dates, without them having to
trace through the logic.

---

## What to test and what not to test

Unit tests cover the **logic** of your functions in isolation. They do not test
GCP connections, BigQuery queries, or GCS reads — those are integration concerns
that require a live environment.

**Good things to test:**
- Data cleaning functions (dropping nulls, renaming columns, filtering rows)
- Transformation logic (aggregations, calculations, date handling)
- Validation checks (does this dataframe have the expected columns?)
- Edge cases (empty input, unexpected data types, boundary values)

**Do not try to test:**
- Functions that call `bq_project_query()`, `bq_table_upload()`, etc.
- Functions that read from or write to GCS
- The pipeline end-to-end (that is an integration test, run separately)

The pattern is: write your logic as pure functions that take data as input and
return data as output, with no side effects. Then write unit tests for those
functions. The BigQuery/GCS calls are thin wrappers around those functions.

**Example — untestable version:**

```r
# Hard to test: mixes logic and I/O
process_data <- function(project, dataset) {
  raw <- bq_project_query(project, "SELECT ...") |> bq_table_download()
  raw |> filter(!is.na(date)) |> mutate(year = year(date))
}
```

**Testable version:**

```r
# Testable: pure function, no I/O
clean_date_column <- function(df) {
  df |> filter(!is.na(date)) |> mutate(year = year(date))
}

# Thin I/O wrapper — not tested directly
fetch_and_process <- function(project, dataset) {
  raw <- bq_project_query(project, "SELECT ...") |> bq_table_download()
  clean_date_column(raw)
}
```

Now `clean_date_column` can be tested with any data frame you construct in
your test file.

---

## Running tests locally

### Python (pytest)

From inside the devcontainer or your WSL2 terminal:

```bash
# Run all tests
pytest tests/ -v

# Run a specific test file
pytest tests/test_pipeline.py -v

# Run a specific test by name
pytest tests/test_pipeline.py::test_add_processed_timestamp_adds_column -v

# Show output (print statements) from tests
pytest tests/ -v -s
```

### R (testthat)

```bash
# Run all tests in the testthat directory
Rscript -e "testthat::test_dir('tests/testthat', reporter='progress')"

# Run a specific test file
Rscript -e "testthat::test_file('tests/testthat/test_pipeline.R')"
```

From within an R session (in the Positron console):

```r
# Load testthat and run tests interactively
library(testthat)
test_dir("tests/testthat")
```

---

## Writing pytest tests (Python)

Pytest discovers tests automatically in files named `test_*.py` or `*_test.py`,
in functions whose names start with `test_`.

### Basic structure

```python
# tests/test_transform.py

import pytest
import pandas as pd

# Import the function you want to test
from src.transform import clean_nulls, add_processed_timestamp


def test_clean_nulls_removes_null_rows():
    df = pd.DataFrame({"id": [1, 2, None], "value": [10, 20, 30]})
    result = clean_nulls(df, column="id")
    assert len(result) == 2


def test_clean_nulls_preserves_other_columns():
    df = pd.DataFrame({"id": [1, None], "value": [10, 20]})
    result = clean_nulls(df, column="id")
    assert "value" in result.columns


def test_add_processed_timestamp_adds_column():
    df = pd.DataFrame({"id": [1]})
    result = add_processed_timestamp(df)
    assert "processed_at" in result.columns
```

### Testing for expected errors

```python
def test_clean_nulls_raises_on_missing_column():
    df = pd.DataFrame({"id": [1, 2]})
    with pytest.raises(KeyError):
        clean_nulls(df, column="nonexistent_column")
```

### Parameterised tests — testing many inputs at once

```python
@pytest.mark.parametrize("input_val, expected", [
    (0, 0),
    (10, 100),
    (-5, 25),
])
def test_square(input_val, expected):
    assert square(input_val) == expected
```

### Fixtures — shared setup

```python
@pytest.fixture
def sample_dataframe():
    return pd.DataFrame({
        "id": [1, 2, 3],
        "date": ["2024-01-01", "2024-01-02", None],
        "value": [10.0, 20.0, 30.0],
    })


def test_clean_nulls_on_real_shaped_data(sample_dataframe):
    result = clean_nulls(sample_dataframe, column="date")
    assert len(result) == 2
```

> **Further reading**: [pytest documentation](https://docs.pytest.org)

---

## Writing testthat tests (R)

Testthat discovers tests in files named `test-*.R` or `test_*.R` inside the
`tests/testthat/` directory.

### Basic structure

```r
# tests/testthat/test_transform.R

library(testthat)

# Source the file containing the functions you want to test.
# Adjust the path based on your project structure.
source("/workspace/src/transform.R")


test_that("clean_nulls removes rows where the specified column is NA", {
  df <- data.frame(id = c(1, 2, NA), value = c(10, 20, 30))
  result <- clean_nulls(df, column = "id")
  expect_equal(nrow(result), 2)
})

test_that("clean_nulls preserves all other columns", {
  df <- data.frame(id = c(1, NA), value = c(10, 20))
  result <- clean_nulls(df, column = "id")
  expect_true("value" %in% names(result))
})

test_that("clean_nulls returns a data frame", {
  df <- data.frame(id = c(1, 2), value = c(10, 20))
  result <- clean_nulls(df, column = "id")
  expect_s3_class(result, "data.frame")
})
```

### Common testthat expectations

```r
expect_equal(result, expected)          # exact equality
expect_identical(result, expected)      # exact equality including type
expect_true(condition)                  # condition is TRUE
expect_false(condition)                 # condition is FALSE
expect_null(result)                     # result is NULL
expect_length(result, n)                # length/nrow is n
expect_s3_class(result, "data.frame")   # result is a data.frame
expect_error(expr, regexp)              # expression throws an error
expect_warning(expr, regexp)            # expression raises a warning
expect_message(expr, regexp)            # expression prints a message
expect_contains(result, expected)       # result contains expected values (testthat 3.x)
```

### Testing with approximate values

Floating point arithmetic does not produce exact results. Use `expect_equal`
with a tolerance for calculations:

```r
test_that("rate calculation is approximately correct", {
  result <- calculate_rate(numerator = 1, denominator = 3)
  expect_equal(result, 0.333, tolerance = 0.001)
})
```

### Testing that errors are thrown

```r
test_that("function errors on negative input", {
  expect_error(
    square_root(-1),
    regexp = "Input must be non-negative"
  )
})
```

### Shared setup with `setup.R`

For setup code that applies to all tests in the directory (loading libraries,
creating shared fixtures), create `tests/testthat/setup.R`:

```r
# tests/testthat/setup.R
library(dplyr)
library(lubridate)

# A sample dataset used in multiple test files
sample_df <- data.frame(
  id    = 1:5,
  date  = as.Date("2024-01-01") + 0:4,
  value = c(10, 20, NA, 40, 50)
)
```

Variables defined in `setup.R` are available in all test files.

> **Further reading**: [testthat documentation](https://testthat.r-lib.org)

### One test_that per behaviour

Each `test_that()` block should test exactly one behaviour. When a test fails, a narrow, well-named block tells you immediately what broke.

```r
# Good — one behaviour per block, descriptive names
test_that("records with NA admission_date are removed", {
  df <- data.frame(
    patient_id     = c(1L, 2L, 3L),
    admission_date = as.Date(c("2024-01-15", NA, "2024-03-20"))
  )
  result <- clean_admission_dates(df)
  expect_equal(nrow(result), 2L)
  expect_false(any(is.na(result$admission_date)))
})

test_that("future dates are removed and a warning is raised", {
  df <- data.frame(
    patient_id     = c(1L, 2L),
    admission_date = as.Date(c("2024-01-15", "2099-01-01"))
  )
  expect_warning(result <- clean_admission_dates(df), "future")
  expect_equal(nrow(result), 1L)
})
```

Two behaviours → two test blocks. If only the future-date logic breaks, you see exactly which block fails.

### What a good pipeline unit test looks like

Three properties matter for pipeline code:

| Property | Why it matters |
|---|---|
| **Deterministic** | No `sample()` without `set.seed()`, no `Sys.Date()` without mocking — the test must return the same result every time |
| **No external calls** | No BigQuery, GCS, or network access — the test must pass in a CI environment with no GCP credentials |
| **Tests one behaviour** | One `test_that()` per behaviour — when something breaks, you know exactly what |

A test that calls `Sys.Date()` directly will pass today and fail in three months when the test data becomes "future dates". Replace it with a fixed date:

```r
# Fragile — result depends on when you run it
test_that("future dates are removed", {
  df <- data.frame(date = c(Sys.Date() - 1, Sys.Date() + 1))
  expect_equal(nrow(remove_future(df)), 1L)
})

# Robust — result is always the same
test_that("future dates are removed", {
  df <- data.frame(date = as.Date(c("2024-01-01", "2099-01-01")))
  expect_equal(nrow(remove_future(df, cutoff = as.Date("2025-01-01"))), 1L)
})
```

### The GitHub Actions connection

When you open a pull request, GitHub runs your tests automatically. The command it runs is identical to what you run locally:

```bash
# In CI (GitHub Actions) — tests live in the pipeline-template subdirectory
Rscript -e "testthat::test_dir('pipeline-template/tests/testthat', reporter = 'progress')"

# Locally (inside the Docker container, from /workspace)
Rscript -e "testthat::test_dir('tests/testthat', reporter = 'progress')"
```

The test runner is the same; only the path differs. Locally, your project sits directly at `/workspace`. In CI, the template lives in `pipeline-template/`. If your tests pass locally, they will pass in CI — the test logic is what matters, not the directory name.

If tests fail in CI but pass locally, the difference is almost always a package that is installed on your machine but not in the Docker image. Check the test output for `could not find package` or `there is no package called` errors — then request that package be added to the base image (see [How the Pipeline Works](architecture.md)).

The test workflow acts as a gatekeeper: code cannot be merged until tests pass. This is what makes it safe for multiple people to work on the same pipeline — everyone's changes are checked before they reach `main`.

---

## Test naming conventions

A good test name reads like a sentence describing the expected behaviour:

| Good | Poor |
|---|---|
| `test_clean_nulls_removes_rows_where_id_is_null` | `test1` |
| `test_add_timestamp_does_not_mutate_input` | `test_function` |
| `test_rate_calculation_returns_value_between_zero_and_one` | `test_rate` |

When a test fails in CI, the name is the first thing you see. A descriptive
name tells you immediately what broke without having to read the test body.

---

## When tests fail in CI

If your pull request shows a failing test, click **Details** next to the status
check on GitHub to see the full output. The failure message will show:
- Which test failed
- What value was expected vs what was actually returned
- The line number in your test file

Reproduce it locally:

```bash
# Python
pytest tests/test_pipeline.py::test_name_that_failed -v

# R
Rscript -e "testthat::test_file('tests/testthat/test_pipeline.R')"
```

Fix the code (or the test if the expectation was wrong), commit, and push.
The CI tests will re-run automatically.

---

## Tests are not a bureaucratic requirement

It is common to see tests as overhead — something you write to satisfy a process
rather than because they are useful. The payoff is not immediate; it accumulates
over time as the codebase grows and changes.

A good indicator that tests are working for you: when you refactor a function
and the tests still pass, you can be confident you have not broken anything. When
they fail, they tell you exactly what changed in behaviour. That confidence is
worth the upfront investment.

Start with the most important logic in your pipeline — the transformation or
calculation that, if wrong, would produce incorrect outputs silently. Test that
first. Add more tests as you encounter bugs: when you find a bug, write a test
that would have caught it before fixing it, so it cannot regress.
