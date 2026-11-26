"""Offline parts of scripts/radar/osm_pbf.py (Geofabrik extracts): no
network, no pyosmium needed."""

from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path
from typing import Any

import pytest

from packages.core.domain.geo.countries import get_radar_country

ROOT = Path(__file__).resolve().parents[2]


def _load() -> Any:
    scripts = str(ROOT / "scripts" / "radar")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    return importlib.import_module("osm_pbf")


def test_extracts_and_file_names() -> None:
    pbf = _load()
    assert pbf.extract_url("AU") == (
        "https://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf"
    )
    # The radar's GB includes Northern Ireland: the United Kingdom extract.
    assert pbf.extract_url("GB").endswith("/europe/united-kingdom-latest.osm.pbf")
    assert pbf.pbf_path(Path("E:/x"), "DE") == Path("E:/x/germany-latest.osm.pbf")
    assert set(pbf.EXTRACTS) == {"IT", "DE", "FR", "ES", "GB", "AU"}
    assert not pbf.outside_repository(ROOT / ".local" / "radar")
    assert pbf.outside_repository(ROOT.parent / "elsewhere")


def test_way_centre_is_the_bounding_box_centre_like_overpass() -> None:
    pbf = _load()
    assert pbf._center([(1.0, 10.0), (3.0, 14.0), (2.0, 11.0)]) == {"lat": 2.0, "lon": 12.0}
    assert pbf._center([]) is None


def test_an_existing_file_is_not_downloaded_again(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pbf = _load()
    target = pbf.pbf_path(tmp_path, "AU")
    target.write_bytes(b"x")

    def no_network(*args: object, **kwargs: object) -> None:
        raise AssertionError("no request expected")

    monkeypatch.setattr(pbf.request, "urlopen", no_network)
    assert pbf.download("AU", tmp_path, local_dir=tmp_path) == target
    assert not (tmp_path / "requests.log").exists()


def test_a_429_stops_geofabrik_without_retry(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pbf = _load()
    calls: list[str] = []

    def answer_429(req: Any, timeout: float = 0) -> Any:
        calls.append(req.full_url)
        raise pbf.error.HTTPError(req.full_url, 429, "Too Many Requests", {}, None)  # type: ignore[arg-type]

    monkeypatch.setattr(pbf.request, "urlopen", answer_429)
    with pytest.raises(pbf.HostStoppedError):
        pbf.download("AU", tmp_path / "pbf", local_dir=tmp_path)
    rows = [json.loads(line) for line in (tmp_path / "requests.log").read_text().splitlines()]
    assert [row["esito"] for row in rows] == [429]
    assert rows[0]["nome"] == "QuokkaImport/1.0"
    assert not list((tmp_path / "pbf").glob("*"))
    # Stopped for good: the next run sends nothing.
    with pytest.raises(pbf.HostStoppedError):
        pbf.download("AU", tmp_path / "pbf", local_dir=tmp_path)
    assert len(calls) == 1


def test_places_outside_the_country_are_dropped() -> None:
    pbf = _load()
    france = get_radar_country("FR")
    assert france is not None
    paris = {"type": "node", "id": 1, "lat": 48.86, "lon": 2.35, "tags": {"amenity": "veterinary"}}
    # La Réunion is in the French extract, not in the radar's France.
    reunion = {**paris, "id": 2, "lat": -21.1, "lon": 55.5}
    not_a_pet_place = {**paris, "id": 3, "tags": {"amenity": "bench"}}
    places, kept = pbf.map_elements([paris, reunion, not_a_pet_place, paris], france)
    assert list(places) == ["node/1"]
    assert kept == [paris, paris]
