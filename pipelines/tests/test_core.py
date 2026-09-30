"""Offline tests for the shared helpers (geo constants and the BigQuery loader)."""

import sys
import types

import pytest

from ectwin_pipelines import bq_load, geo


def test_bboxes_nest_inside_ecuador():
    lon_min, lat_min, lon_max, lat_max = geo.ECUADOR_BBOX
    for box in (geo.MAINLAND_BBOX, geo.GALAPAGOS_BBOX):
        assert lon_min <= box[0] < box[2] <= lon_max
        assert lat_min <= box[1] < box[3] <= lat_max


@pytest.mark.parametrize(
    "lon,lat,expected",
    [(-79.9, -2.2, True), (-90.3, -0.7, True), (-70.0, -2.0, False), (-80.0, 3.0, False)],
)
def test_in_bbox(lon, lat, expected):
    assert geo.in_bbox(lon, lat) is expected


def test_elnino_seasons_are_ordered():
    for start, end in geo.ELNINO_SEASONS.values():
        assert start < end


def test_resolve_targets_finds_declared_files(tmp_path, monkeypatch):
    module = types.ModuleType("fake_pipeline")
    module.BQ_TARGETS = {"a": "ectwin_commons.a", "missing": "ectwin_commons.missing"}
    monkeypatch.setitem(sys.modules, "fake_pipeline", module)
    (tmp_path / "a.parquet").write_bytes(b"PAR1")
    pairs = bq_load.resolve_targets("fake_pipeline", str(tmp_path))
    assert [(p.name, t) for p, t in pairs] == [("a.parquet", "ectwin_commons.a")]


def test_main_requires_project(monkeypatch):
    monkeypatch.delenv("GCP_PROJECT_ID", raising=False)
    with pytest.raises(SystemExit):
        bq_load.main(["--file", "x.parquet", "--table", "ectwin_commons.x"])


def test_load_parquet_rejects_bad_table_name(tmp_path):
    pytest.importorskip("google.cloud.bigquery")
    with pytest.raises(ValueError):
        bq_load.load_parquet("p", tmp_path / "x.parquet", "no_dataset")
