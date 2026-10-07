from __future__ import annotations

import json
import logging
import math
import time
from datetime import UTC, datetime
from urllib import error, parse, request

from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
)
from packages.core.domain.radar_places.models import OSM_SOURCE_NAME, RadarPlace
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError

# A place tagged with its category but no name is still a real place:
# measured within 10 km of Milan, 22 of 108 veterinarians and 347 of 364
# dog parks have no name in OSM. A generic label beats dropping them.
_DEFAULT_NAMES = {
    "veterinary": "Veterinario",
    "grooming": "Toelettatura",
    "shop": "Negozio per animali",
    "school": "Addestramento",
    "pet_sitting": "Pet sitter",
    "breeder": "Allevamento",
    "hotel": "Pensione per animali",
    "dog_park": "Area cani",
    "shelter": "Rifugio per animali",
}

_OSM_SPECIES = {
    "dog": "dog",
    "dogs": "dog",
    "cat": "cat",
    "cats": "cat",
    "bird": "bird",
    "birds": "bird",
    "fish": "fish",
    "reptile": "reptile_amphibian",
    "reptiles": "reptile_amphibian",
    "rabbit": "small_mammal",
    "rodent": "small_mammal",
    "rodents": "small_mammal",
    "horse": "other",
    "horses": "other",
}

_logger = logging.getLogger(__name__)

# Tag filters of the pet categories, one Overpass statement each.
OSM_SELECTORS = (
    '["amenity"="veterinary"]',
    '["shop"="pet"]',
    '["shop"="pet_grooming"]',
    '["amenity"="animal_boarding"]',
    '["amenity"="animal_training"]',
    '["amenity"="animal_breeding"]',
    '["office"="pet_sitting"]',
    '["craft"="dog_walker"]',
    '["leisure"="dog_park"]',
    '["amenity"="animal_shelter"]',
)

# Tags worth showing on a place card when the mapper recorded them. Only
# what OSM states is passed on: an absent key means "unknown", never "no".
_DETAIL_TAGS = (
    "barrier",
    "lit",
    "surface",
    "access",
    "drinking_water",
    "wheelchair",
    "dog",
    "fee",
    "animal_shelter:adoption",
)

# Whole import, retries included. Kept well under a minute: the caller is
# an HTTP request with a person waiting, and the app retries on its own.
_TOTAL_TIME_BUDGET_SECONDS = 40.0
_MIN_ATTEMPT_SECONDS = 8.0
_RATE_LIMIT_WAITS_SECONDS = (5.0, 10.0)
_MIN_QUERY_TIMEOUT_SECONDS = 15


class _RateLimitedError(ProviderError):
    """HTTP 429: the server is fine, this client just has to wait."""


class OverpassRadarPlacesSource:
    """OpenStreetMap place source backed by an Overpass API interpreter."""

    name = "openstreetmap_overpass"

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def fetch_places(
        self,
        request_data: RequestRadarPlacesIngestionInput,
    ) -> list[RadarPlace]:
        radius_km = min(
            request_data.radius_km,
            self._settings.overpass_max_radius_km,
        )
        radius_meters = max(1, int(round(radius_km * 1000)))
        # Overpass admits a query only if the time it declares fits the
        # server's current load, so asking for the configured maximum on a
        # small area gets it rejected (429/504) when a modest request
        # would pass. Declare what the radius actually needs.
        query_timeout = min(
            self._settings.overpass_timeout_seconds,
            max(_MIN_QUERY_TIMEOUT_SECONDS, math.ceil(radius_km * 0.6)),
        )
        query = _build_overpass_query(
            latitude=request_data.center_latitude,
            longitude=request_data.center_longitude,
            radius_meters=radius_meters,
            timeout_seconds=query_timeout,
        )
        body = parse.urlencode({"data": query}).encode("utf-8")
        elements = self._fetch_elements(body, query_timeout=query_timeout)

        window = request_data.coverage_window()
        fetched_at = datetime.now(UTC)
        return [
            place
            for element in elements
            if isinstance(element, dict)
            for place in [
                self._map_element(
                    element,
                    request_data=request_data,
                    coverage_key=window.coverage_key,
                    fetched_at=fetched_at,
                )
            ]
            if place is not None
        ]

    def _fetch_elements(self, body: bytes, *, query_timeout: int) -> list[object]:
        """Tries the main interpreter, then each fallback mirror. The
        public Overpass servers are a shared free resource and routinely
        answer 429/504 under load, so one busy server must not make the
        whole radar unavailable. Bounded by one overall time budget so a
        slow chain cannot outlive the client's own timeout."""
        deadline = time.monotonic() + _TOTAL_TIME_BUDGET_SECONDS
        last_error: ProviderError | None = None
        for url in (self._settings.overpass_base_url, *self._settings.overpass_fallback_urls):
            for wait_seconds in (0.0, *_RATE_LIMIT_WAITS_SECONDS):
                # 429 means "your slot frees up in a few seconds": waiting
                # on the same server beats moving to a slower mirror.
                if wait_seconds and deadline - time.monotonic() > wait_seconds:
                    time.sleep(wait_seconds)
                remaining = deadline - time.monotonic()
                if last_error is not None and remaining < _MIN_ATTEMPT_SECONDS:
                    raise last_error
                try:
                    return self._request_elements(
                        url,
                        body,
                        timeout=min(query_timeout + 5, remaining),
                    )
                except _RateLimitedError as exc:
                    last_error = exc
                    _logger.warning("Overpass rate limited by %s", parse.urlsplit(url).netloc)
                except ProviderError as exc:
                    last_error = exc
                    _logger.warning(
                        "Overpass attempt failed on %s: %s",
                        parse.urlsplit(url).netloc,
                        str(exc)[:200],
                    )
                    break
        assert last_error is not None
        raise last_error

    def _request_elements(self, url: str, body: bytes, *, timeout: float) -> list[object]:
        http_request = request.Request(
            url=url,
            data=body,
            headers={
                "Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
                "Accept": "application/json",
                "User-Agent": self._settings.overpass_user_agent,
            },
            method="POST",
        )

        try:
            with request.urlopen(http_request, timeout=timeout) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")[:500]
            error_type = _RateLimitedError if exc.code == 429 else ProviderError
            raise error_type(f"Overpass request failed with status {exc.code}: {detail}") from exc
        except error.URLError as exc:
            raise ProviderError(f"Unable to reach Overpass API: {exc.reason}") from exc
        except TimeoutError as exc:
            raise ProviderError("Overpass request timed out") from exc
        except json.JSONDecodeError as exc:
            raise ProviderError("Overpass response was not valid JSON") from exc

        elements = payload.get("elements", []) if isinstance(payload, dict) else None
        if not isinstance(elements, list):
            raise ProviderError("Overpass response did not contain an elements list")
        return elements

    def _map_element(
        self,
        element: dict[str, object],
        *,
        request_data: RequestRadarPlacesIngestionInput,
        coverage_key: str,
        fetched_at: datetime,
    ) -> RadarPlace | None:
        return map_osm_element(
            element,
            owner_id=request_data.owner_id,
            coverage_key=coverage_key,
            fetched_at=fetched_at,
            source_name=self.name,
        )


def map_osm_element(
    element: dict[str, object],
    *,
    owner_id: str,
    coverage_key: str,
    fetched_at: datetime,
    source_name: str = OSM_SOURCE_NAME,
) -> RadarPlace | None:
    """One Overpass element as a radar place, or None when it is not one
    of the pet categories or has no usable position. Shared by the live
    source and by the offline importer (scripts/radar/)."""
    element_type = _read_string(element.get("type"))
    element_id = element.get("id")
    if element_type not in {"node", "way", "relation"} or not isinstance(element_id, int):
        return None

    tags_raw = element.get("tags")
    tags = (
        {str(key): str(value) for key, value in tags_raw.items()}
        if isinstance(tags_raw, dict)
        else {}
    )
    classification = _classify_tags(tags)
    if classification is None:
        return None
    place_type, subtype = classification

    latitude, longitude = _read_coordinates(element)
    if latitude is None or longitude is None:
        return None

    name = _first_tag(tags, "name", "brand", "operator") or _DEFAULT_NAMES.get(place_type)
    if not name:
        return None

    source_external_id = f"{element_type}/{element_id}"
    source_url = f"https://www.openstreetmap.org/{source_external_id}"
    return RadarPlace(
        owner_id=owner_id,
        coverage_key=coverage_key,
        place_type=place_type,
        subtype=subtype,
        name=name,
        summary=_first_tag(tags, "description"),
        opening_hours=_first_tag(tags, "opening_hours"),
        species=_read_species(tags, place_type=place_type, subtype=subtype),
        details=_read_details(tags),
        city=_first_tag(tags, "addr:city", "addr:town", "addr:village"),
        address_label=_build_address_label(tags),
        latitude=latitude,
        longitude=longitude,
        source_name=source_name,
        source_external_id=source_external_id,
        external_record_id=source_external_id,
        source_url=source_url,
        phone=_first_tag(tags, "contact:phone", "phone"),
        website_url=_first_tag(tags, "contact:website", "website") or source_url,
        is_pet_friendly=True,
        tags=_display_tags(tags, subtype=subtype),
        source_payload=element,
        source_fetched_at=fetched_at,
        freshness_status="fresh",
        status="active",
    )


def _build_overpass_query(
    *,
    latitude: float,
    longitude: float,
    radius_meters: int,
    timeout_seconds: int,
) -> str:
    around = f"around:{radius_meters},{latitude:.6f},{longitude:.6f}"
    statements = "\n".join(f"  nwr({around}){selector};" for selector in OSM_SELECTORS)
    return f"[out:json][timeout:{timeout_seconds}];\n(\n{statements}\n);\nout center tags qt;"


def build_overpass_area_query(*, iso_3166_2: str, timeout_seconds: int) -> str:
    """Every pet place inside one administrative area (an Italian region,
    e.g. "IT-25"), for the offline importer."""
    statements = "\n".join(f"  nwr(area.a){selector};" for selector in OSM_SELECTORS)
    return (
        f'[out:json][timeout:{timeout_seconds}];\narea["ISO3166-2"="{iso_3166_2}"]->.a;\n'
        f"(\n{statements}\n);\nout center tags qt;"
    )


def _read_details(tags: dict[str, str]) -> dict[str, str]:
    return {key: tags[key].strip() for key in _DETAIL_TAGS if tags.get(key, "").strip()}


def _read_coordinates(element: dict[str, object]) -> tuple[float | None, float | None]:
    latitude = element.get("lat")
    longitude = element.get("lon")
    if isinstance(latitude, (int, float)) and isinstance(longitude, (int, float)):
        return float(latitude), float(longitude)

    center = element.get("center")
    if not isinstance(center, dict):
        return None, None
    center_lat = center.get("lat")
    center_lon = center.get("lon")
    if isinstance(center_lat, (int, float)) and isinstance(center_lon, (int, float)):
        return float(center_lat), float(center_lon)
    return None, None


def _classify_tags(tags: dict[str, str]) -> tuple[str, str] | None:
    amenity = tags.get("amenity", "").strip().lower()
    shop = tags.get("shop", "").strip().lower()
    office = tags.get("office", "").strip().lower()
    craft = tags.get("craft", "").strip().lower()
    leisure = tags.get("leisure", "").strip().lower()

    if amenity == "animal_shelter":
        return "shelter", "amenity:animal_shelter"
    if amenity == "veterinary":
        return "veterinary", "amenity:veterinary"
    if shop == "pet_grooming":
        return "grooming", "shop:pet_grooming"
    if shop == "pet":
        return "shop", "shop:pet"
    if amenity == "animal_training":
        return "school", "amenity:animal_training"
    if amenity == "animal_breeding":
        return "breeder", "amenity:animal_breeding"
    if amenity == "animal_boarding":
        return "hotel", "amenity:animal_boarding"
    if office == "pet_sitting":
        return "pet_sitting", "office:pet_sitting"
    if craft == "dog_walker":
        return "pet_sitting", "craft:dog_walker"
    if leisure == "dog_park":
        return "dog_park", "leisure:dog_park"
    return None


def _read_species(tags: dict[str, str], *, place_type: str, subtype: str) -> list[str]:
    """Species a place is specifically for, in the app's canonical species
    keys (packages/core/domain/pet_profile/species.py). Empty means "not
    stated", which callers treat as relevant to every species."""
    if place_type == "dog_park" or subtype == "craft:dog_walker":
        return ["dog"]
    found: list[str] = []
    for key in ("animal_boarding", "animal_breeding", "animal_training", "animal_shelter", "pets"):
        for raw in tags.get(key, "").lower().replace(",", ";").split(";"):
            species = _OSM_SPECIES.get(raw.strip())
            if species and species not in found:
                found.append(species)
    return found


def _build_address_label(tags: dict[str, str]) -> str | None:
    street = _first_tag(tags, "addr:street", "addr:place")
    house_number = _first_tag(tags, "addr:housenumber")
    locality = _first_tag(tags, "addr:city", "addr:town", "addr:village")
    postcode = _first_tag(tags, "addr:postcode")

    street_line = " ".join(item for item in (street, house_number) if item)
    parts = [item for item in (street_line or None, postcode, locality) if item]
    return ", ".join(parts) or None


def _display_tags(tags: dict[str, str], *, subtype: str) -> list[str]:
    values = [subtype]
    for key in ("opening_hours", "wheelchair", "operator", "brand"):
        value = tags.get(key, "").strip()
        if value:
            values.append(f"{key}={value}")
    return values


def _first_tag(tags: dict[str, str], *keys: str) -> str | None:
    for key in keys:
        value = tags.get(key, "").strip()
        if value:
            return value
    return None


def _read_string(value: object) -> str | None:
    text = value.strip() if isinstance(value, str) else None
    return text or None
