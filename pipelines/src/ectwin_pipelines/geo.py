"""Shared geography constants for Ecuador."""

from __future__ import annotations

# Bounding boxes (lon_min, lat_min, lon_max, lat_max), WGS84.
# Whole country including Galápagos, as used across the plan (docs D13).
ECUADOR_BBOX = (-92.1, -5.1, -75.1, 1.7)
# Mainland only, and Galápagos only (used to avoid scanning ocean cells).
MAINLAND_BBOX = (-81.2, -5.1, -75.1, 1.7)
GALAPAGOS_BBOX = (-92.1, -1.5, -89.1, 0.8)

# El Niño seasons used as analogs (docs D3). Keys are labels; values are
# (start, end) ISO dates of the wet season most affected on the coast.
ELNINO_SEASONS = {
    "1982-83": ("1982-10-01", "1983-07-31"),
    "1997-98": ("1997-10-01", "1998-07-31"),
    "2015-16": ("2015-10-01", "2016-06-30"),
    "2017-costero": ("2017-01-01", "2017-05-31"),
    "2023-24": ("2023-06-01", "2024-05-31"),
}


def in_bbox(lon: float, lat: float, bbox: tuple[float, float, float, float] = ECUADOR_BBOX) -> bool:
    """Return True if the point lies inside the bounding box (edges inclusive)."""
    lon_min, lat_min, lon_max, lat_max = bbox
    return lon_min <= lon <= lon_max and lat_min <= lat <= lat_max
