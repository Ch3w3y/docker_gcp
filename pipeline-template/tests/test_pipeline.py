# tests/test_pipeline.py
#
# Unit tests for Python functions in this pipeline.
# Run with: pytest tests/
#
# These tests cover pure logic only — no GCP connections.
# Anything that touches BigQuery or GCS should be tested with mocks
# or in an integration test suite run separately.

import pytest
import pandas as pd


# ---------------------------------------------------------------------------
# Example: testing a transformation function
# ---------------------------------------------------------------------------

def add_processed_timestamp(df: pd.DataFrame) -> pd.DataFrame:
    """Example transform function from src/transform.py."""
    df = df.copy()
    df["processed_at"] = pd.Timestamp.utcnow()
    return df


def test_add_processed_timestamp_adds_column():
    df = pd.DataFrame({"id": [1, 2], "value": [10, 20]})
    result = add_processed_timestamp(df)
    assert "processed_at" in result.columns


def test_add_processed_timestamp_preserves_rows():
    df = pd.DataFrame({"id": [1, 2, 3]})
    result = add_processed_timestamp(df)
    assert len(result) == 3


def test_add_processed_timestamp_does_not_mutate_input():
    df = pd.DataFrame({"id": [1]})
    add_processed_timestamp(df)
    assert "processed_at" not in df.columns
