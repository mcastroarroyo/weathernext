"""Load pipeline outputs (Parquet) into BigQuery.

Usage:
    python -m ectwin_pipelines.bq_load --project <PROJECT_ID> \
        --file out/grrr_outlets.parquet --table ectwin_commons.grrr_outlets

    # or load every file a module declares in its BQ_TARGETS:
    python -m ectwin_pipelines.bq_load --project <PROJECT_ID> \
        --module ectwin_pipelines.grrr_ecuador --dir out/

The project comes from ``--project`` or the ``GCP_PROJECT_ID`` environment
variable; credentials come from the environment (Workload Identity Federation
in CI). Tables are replaced (WRITE_TRUNCATE) unless ``--append`` is given.
Datasets must already exist (created by ``infra/testing``).
"""

from __future__ import annotations

import argparse
import importlib
import os
import sys
from pathlib import Path


def resolve_targets(module_name: str, directory: str) -> list[tuple[Path, str]]:
    """Return (file, dataset.table) pairs for a module's BQ_TARGETS found in ``directory``."""
    module = importlib.import_module(module_name)
    targets = getattr(module, "BQ_TARGETS", None)
    if not targets:
        raise SystemExit(f"{module_name} declares no BQ_TARGETS")
    pairs = []
    for stem, table in targets.items():
        path = Path(directory) / f"{stem}.parquet"
        if path.exists():
            pairs.append((path, table))
        else:
            print(f"skip {stem}: {path} not found", file=sys.stderr)
    return pairs


def load_parquet(project: str, path: Path, table: str, append: bool = False) -> int:
    """Load one Parquet file into ``project.table``; return the resulting row count."""
    from google.cloud import bigquery  # imported lazily so offline tests need no GCP libs

    if table.count(".") != 1:
        raise ValueError(f"table must be 'dataset.table', got {table!r}")
    client = bigquery.Client(project=project)
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=(
            bigquery.WriteDisposition.WRITE_APPEND if append else bigquery.WriteDisposition.WRITE_TRUNCATE
        ),
        labels={"app": "ectwin", "component": "bq_load"},
    )
    with open(path, "rb") as fh:
        job = client.load_table_from_file(fh, f"{project}.{table}", job_config=job_config)
    job.result()
    return client.get_table(f"{project}.{table}").num_rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", default=os.environ.get("GCP_PROJECT_ID"))
    parser.add_argument("--file", help="Parquet file to load")
    parser.add_argument("--table", help="dataset.table target for --file")
    parser.add_argument("--module", help="module whose BQ_TARGETS to load, e.g. ectwin_pipelines.grrr_ecuador")
    parser.add_argument("--dir", default=".", help="directory holding the module's outputs")
    parser.add_argument("--append", action="store_true")
    args = parser.parse_args(argv)

    if not args.project:
        parser.error("set --project or GCP_PROJECT_ID")
    if args.module:
        pairs = resolve_targets(args.module, args.dir)
    elif args.file and args.table:
        pairs = [(Path(args.file), args.table)]
    else:
        parser.error("give --module (with --dir) or --file and --table")

    for path, table in pairs:
        rows = load_parquet(args.project, path, table, append=args.append)
        print(f"loaded {path} -> {table}: {rows} rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
