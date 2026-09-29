from __future__ import annotations

import json
from datetime import UTC, datetime
from urllib import error, parse, request

from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionInput,
)
from packages.core.domain.coverage.models import RadarCoverageWindow
from packages.core.domain.radar_places.models import RadarPlace
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError


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
        query = _build_overpass_query(
            latitude=request_data.center_latitude,
            longitude=request_data.center_longitude,
            radius_meters=radius_meters,
            timeout_seconds=self._settings.overpass_timeout_seconds,
        )
        body = parse.urlencode({"data": query}).encode("utf-8")
        http_request = request.Request(
            url=self._settings.overpass_base_url,
            data=body,
            headers={
                "Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
                "Accept": "application/json",
                "User-Agent": self._settings.overpass_user_agent,
            },
            method="POST",
        )

        try:
            with request.urlopen(
                http_request,
                timeout=self._settings.overpass_timeout_seconds + 5,
            ) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")[:500]
            raise ProviderError(
                f"Overpass request failed with status {exc.code}: {detail}"
            ) from exc
        except error.URLError as exc:
            raise ProviderError(f"Unable to reach Overpass API: {exc.reason}") from exc
        except TimeoutError as exc:
            raise ProviderError("Overpass request timed out") from exc
        except json.JSONDecodeError as exc:
            raise ProviderError("Overpass response was not valid JSON") from exc

        elements = payload.get("elements", [])
        if not isinstance(elements, list):
            raise ProviderError("Overpass response did not contain an elements list")

        window = RadarCoverageWindow(
            owner_id=request_data.owner_id,
            center_latitude=request_data.center_latitude,
            center_longitude=request_data.center_longitude,
            radius_km=request_data.radius_km,
            freshness_ttl_hours=request_data.freshness_ttl_hours,
        )
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

    def _map_element(
        self,
        element: dict[str, object],
        *,
        request_data: RequestRadarPlacesIngestionInput,
        coverage_key: str,
        fetched_at: datetime,
    ) -> RadarPlace | None:
        element_type = _read_string(element.get("type"))
        element_id = element.get("id")
        if element_type not in {"node", "way", "relation"} or not isinstance(
            element_id,
            int,
        ):
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

        name = _first_tag(tags, "name", "brand", "operator")
        if not name:
            return None

        source_external_id = f"{element_type}/{element_id}"
        source_url = f"https://www.openstreetmap.org/{source_external_id}"
        address_label = _build_address_label(tags)
        city = _first_tag(tags, "addr:city", "addr:town", "addr:village")
        phone = _first_tag(tags, "contact:phone", "phone")
        website_url = _first_tag(tags, "contact:website", "website")
        summary = _first_tag(tags, "description", "opening_hours")

        return RadarPlace(
            owner_id=request_data.owner_id,
            coverage_key=coverage_key,
            place_type=place_type,
            subtype=subtype,
            name=name,
            summary=summary,
            city=city,
            address_label=address_label,
            latitude=latitude,
            longitude=longitude,
            source_name=self.name,
            source_external_id=source_external_id,
            external_record_id=source_external_id,
            source_url=source_url,
            phone=phone,
            website_url=website_url or source_url,
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
    selectors = (
        '["amenity"="veterinary"]',
        '["shop"="pet"]',
        '["shop"="pet_grooming"]',
        '["amenity"="animal_boarding"]',
        '["amenity"="animal_training"]',
        '["amenity"="animal_breeding"]',
        '["office"="pet_sitting"]',
        '["craft"="dog_walker"]',
    )
    statements = "\n".join(f"  nwr({around}){selector};" for selector in selectors)
    return (
        f"[out:json][timeout:{timeout_seconds}];\n"
        "(\n"
        f"{statements}\n"
        ");\n"
        "out center tags qt;"
    )


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
    return None


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
