"""Offline parts of scripts/radar/osm_pbf.py (Geofabrik trial): no network,
no pyosmium needed."""

from __future__ import annotations

import importlib
import sys
from pathlib import Path
from typing import Any

import pytest

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


def test_way_centre_is_the_bounding_box_centre_like_overpass() -> None:
    pbf = _load()
    assert pbf._center([(1.0, 10.0), (3.0, 14.0), (2.0, 11.0)]) == {"lat": 2.0, "lon": 12.0}
    assert pbf._center([]) is None


def test_an_existing_file_is_not_downloaded_again(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pbf = _load()
    monkeypatch.setattr(pbf, "LOCAL_DIR", tmp_path)
    target = pbf.pbf_path(tmp_path, "AU")
    target.write_bytes(b"x")

    def no_network(*args: object, **kwargs: object) -> None:
        raise AssertionError("no request expected")

    monkeypatch.setattr(pbf.request, "urlopen", no_network)
    assert pbf.download("AU", tmp_path, refresh=False) == target
    assert not (tmp_path / "requests.log").exists()


def test_the_pbf_folder_must_be_outside_the_repository(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    pbf = _load()
    inside = str(ROOT / ".local" / "radar" / "pbf")
    monkeypatch.setattr(
        sys, "argv", ["osm_pbf.py", "--country", "AU", "--pbf-dir", inside, "--download"]
    )
    with pytest.raises(SystemExit):
        pbf.main()
    assert "fuori dal repository" in capsys.readouterr().err
