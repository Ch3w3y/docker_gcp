# src/transform.py
#
# Transform step: read the extracted data, apply business logic, write output.
# Replace the example logic with your own.

import os
import pandas as pd

GCS_DATA_BUCKET = os.environ["GCS_DATA_BUCKET"]

# Read the data written by the R extract step.
raw_data = pd.read_csv("/tmp/raw_data.csv")  # adjust format to match extract.R

print(f"Transforming {len(raw_data)} rows...")

# --- your transformation logic here ---
transformed = raw_data.copy()
transformed["processed_at"] = pd.Timestamp.utcnow()

# Write output for the load step.
transformed.to_csv("/tmp/transformed_data.csv", index=False)
print("Transform complete.")
