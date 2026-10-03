from __future__ import annotations

import json
from typing import Any, cast
from urllib import parse

import pytest

from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
)
from packages.infrastructure.radar_places.overpass_places_source import (
    OverpassRadarPlacesSource,
)
from packages.shared.config.settings import Settings


class _FakeResponse:
    def __enter__(self) -> _FakeResponse:
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def read(self) -> bytes:
        return json.dumps(
            {
                "elements": [
                    {
                        "type": "node",
                        "id": 101,
                        "lat": 45.4629,
                        "lon": 9.1882,
                        "tags": {
                            "amenity": "veterinary",
                            "name": "Veterinario Milano",
                            "addr:street": "Via Torino",
                            "addr:housenumber": "10",
                            "addr:postcode": "20123",
                            "addr:city": "Milano",
                            "contact:phone": "+39 02 1234567",
                            "contact:website": "https://vet.example",
                            "opening_hours": "Mo-Fr 09:00-19:00",
                        },
                    },
                    {
                        "type": "way",
                        "id": 202,
                        "center": {"lat": 45.4701, "lon": 9.2011},
                        "tags": {
                            "shop": "pet_grooming",
                            "name": "Bau Grooming",
                            "addr:city": "Milano",
                        },
                    },
                ]
            }
        ).encode("utf-8")


def test_overpass_source_posts_query_and_maps_osm_elements(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    captured: dict[str, Any] = {}

    def fake_urlopen(http_request: Any, timeout: int) -> _FakeResponse:
        captured["request"] = http_request
        captured["timeout"] = timeout
        return _FakeResponse()

    import packages.infrastructure.radar_places.overpass_places_source as source_module

    monkeypatch.setattr(source_module.request, "urlopen", fake_urlopen)
    settings = Settings(
        ENVIRONMENT="test",
        RADAR_PLACES_PROVIDER="openstreetmap_overpass",
        RADAR_SEARCH_RADIUS_KM=10,
        OVERPASS_BASE_URL="https://overpass.example/api/interpreter",
        OVERPASS_TIMEOUT_SECONDS=25,
        OVERPASS_MAX_RADIUS_KM=10,
        OVERPASS_USER_AGENT="VET-APP-test/1.0",
    )
    source = OverpassRadarPlacesSource(settings)

    places = source.fetch_places(
        RequestRadarPlacesIngestionInput(
            owner_id="test-user",
            center_latitude=45.4642,
            center_longitude=9.1899,
            radius_km=10,
            freshness_ttl_hours=168,
        )
    )

    http_request = cast(Any, captured["request"])
    request_body = parse.parse_qs(http_request.data.decode("utf-8"))
    overpass_query = request_body["data"][0]

    assert http_request.full_url == "https://overpass.example/api/interpreter"
    assert http_request.get_method() == "POST"
    assert http_request.get_header("User-agent") == "VET-APP-test/1.0"
    assert captured["timeout"] == 20
    assert "around:10000,45.464200,9.189900" in overpass_query
    assert '["amenity"="veterinary"]' in overpass_query
    assert '["shop"="pet_grooming"]' in overpass_query
    assert '["amenity"="animal_boarding"]' in overpass_query

    assert len(places) == 2

    veterinary = places[0]
    assert veterinary.owner_id == "test-user"
    assert veterinary.source_name == "openstreetmap_overpass"
    assert veterinary.source_external_id == "node/101"
    assert veterinary.external_record_id == "node/101"
    assert veterinary.name == "Veterinario Milano"
    assert veterinary.place_type == "veterinary"
    assert veterinary.subtype == "amenity:veterinary"
    assert veterinary.address_label == "Via Torino 10, 20123, Milano"
    assert veterinary.city == "Milano"
    assert veterinary.latitude == 45.4629
    assert veterinary.longitude == 9.1882
    assert veterinary.phone == "+39 02 1234567"
    assert veterinary.website_url == "https://vet.example"
    assert veterinary.source_url == "https://www.openstreetmap.org/node/101"
    assert veterinary.freshness_status == "fresh"

    grooming = places[1]
    assert grooming.source_external_id == "way/202"
    assert grooming.place_type == "grooming"
    assert grooming.subtype == "shop:pet_grooming"
    assert grooming.latitude == 45.4701
    assert grooming.longitude == 9.2011
    assert grooming.website_url == "https://www.openstreetmap.org/way/202"
