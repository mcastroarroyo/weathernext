"""GDE-Niño data pipelines.

Each module is a small, testable step that reads public data, clips it to
Ecuador and writes tidy tables (Parquet/CSV) that ``bq_load`` can load into
BigQuery. Modules never hold credentials; GCP access comes from the
environment (Workload Identity Federation in CI, the runner service account
in Cloud Run jobs).
"""

__version__ = "0.1.0"
