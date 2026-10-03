import io
import json
from typing import Any
from urllib import error

import pytest

from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
)
from packages.infrastructure.radar_places import overpass_places_source
from packages.infrastructure.radar_places.overpass_places_source import (
    OverpassRadarPlacesSource,
)
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

_REQUEST = RequestRadarPlacesIngestionInput(
    owner_id="shared",
    center_latitude=45.45,
    center_longitude=9.2,
    radius_km=15,
    freshness_ttl_hours=168,
)


class _OkResponse:
    def __enter__(self) -> "_OkResponse":
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def read(self) -> bytes:
        element = {
            "type": "node",
            "id": 7,
            "lat": 45.46,
            "lon": 9.19,
            "tags": {"amenity": "veterinary", "name": "Veterinario di riserva"},
        }
        return json.dumps({"elements": [element]}).encode("utf-8")


def _settings() -> Settings:
    return Settings(
        ENVIRONMENT="test",
        OVERPASS_BASE_URL="https://main.example/api/interpreter",
        OVERPASS_FALLBACK_URLS=["https://mirror.example/api/interpreter"],
    )


def _overloaded(url: str) -> error.HTTPError:
    return error.HTTPError(url, 504, "Gateway Timeout", None, io.BytesIO(b"busy"))  # type: ignore[arg-type]


def test_falls_back_to_the_mirror_when_the_main_server_is_overloaded(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    called: list[str] = []

    def fake_urlopen(http_request: Any, timeout: float) -> _OkResponse:
        called.append(http_request.full_url)
        if "main.example" in http_request.full_url:
            raise _overloaded(http_request.full_url)
        return _OkResponse()

    monkeypatch.setattr(overpass_places_source.request, "urlopen", fake_urlopen)

    places = OverpassRadarPlacesSource(_settings()).fetch_places(_REQUEST)

    assert called == [
        "https://main.example/api/interpreter",
        "https://mirror.example/api/interpreter",
    ]
    assert [place.name for place in places] == ["Veterinario di riserva"]


def test_raises_the_last_error_when_every_server_fails(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def fake_urlopen(http_request: Any, timeout: float) -> _OkResponse:
        raise _overloaded(http_request.full_url)

    monkeypatch.setattr(overpass_places_source.request, "urlopen", fake_urlopen)

    with pytest.raises(ProviderError, match="504"):
        OverpassRadarPlacesSource(_settings()).fetch_places(_REQUEST)
