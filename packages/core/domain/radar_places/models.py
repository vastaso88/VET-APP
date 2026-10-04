from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator

from packages.core.domain.geo.models import Coordinates

RadarPlaceType = Literal[
    "veterinary",
    "grooming",
    "shop",
    "school",
    "pet_sitting",
    "breeder",
    "hotel",
    "dog_park",
]

OSM_SOURCE_NAME = "openstreetmap_overpass"
OVERTURE_SOURCE_NAME = "overture"

# Fields that only matter while importing or while composing a response
# and are never written to a table.
RADAR_PLACE_TRANSIENT_FIELDS = frozenset(
    {
        "owner_id",
        "external_record_id",
        "source_payload",
        "freshness_status",
        "confirmed_by",
        "confidence",
        "license",
        "release",
    }
)

# Left out of API responses: import bookkeeping, not place data.
RADAR_PLACE_API_EXCLUDED_FIELDS = frozenset(
    {"owner_id", "external_record_id", "source_payload", "freshness_status", "coverage_key"}
)


class RadarPlace(BaseModel):
    """A pet-related business or service from an open data source, as the
    radar serves it. One source per record: fields are never a blend of
    two sources (see `confirmed_by`)."""

    id: str = ""
    owner_id: str = ""
    coverage_key: str
    place_type: str
    subtype: str | None = None
    name: str
    summary: str | None = None
    # Raw OSM `opening_hours` syntax, shown as stated: never used to decide
    # "open now" (unverified data must not drive urgency decisions).
    opening_hours: str | None = None
    # Canonical species keys the place is specifically for; empty = any.
    species: list[str] = Field(default_factory=list)
    # Extra facts stated by the source, shown only when present (dog parks:
    # barrier, lit, surface, access, drinking_water, wheelchair).
    details: dict[str, str] = Field(default_factory=dict)
    city: str | None = None
    address_label: str | None = None
    latitude: float
    longitude: float
    source_name: str
    source_external_id: str
    external_record_id: str | None = None
    source_url: str | None = None
    phone: str | None = None
    website_url: str | None = None
    is_pet_friendly: bool = True
    tags: list[str] = Field(default_factory=list)
    source_payload: dict[str, Any] = Field(default_factory=dict)
    source_fetched_at: datetime | None = None
    freshness_status: str = "fresh"
    status: str = "active"
    # Other sources that list the same place (see dedup.merge_radar_places).
    # Their data is not copied into this record.
    confirmed_by: list[str] = Field(default_factory=list)
    confidence: float | None = None
    license: str | None = None
    release: str | None = None

    @model_validator(mode="after")
    def _assign_id(self) -> "RadarPlace":
        if not self.id:
            self.id = f"{self.coverage_key}|{self.source_name}|{self.source_external_id}"
        if self.place_type == "dog_park" and not self.species:
            # True whatever the source says or stores about species.
            self.species = ["dog"]
        return self

    @property
    def location(self) -> Coordinates:
        return Coordinates(latitude=self.latitude, longitude=self.longitude)


class RadarDataSource(BaseModel):
    """One imported dataset: what it is, under which license, and which
    area and moment the import covers."""

    source: str
    release: str
    license: str
    attribution: str
    url: str | None = None
    place_count: int = 0
    imported_at: datetime
    # Area the import fully covers; a point inside it never needs a live
    # provider call for this source.
    min_latitude: float | None = None
    max_latitude: float | None = None
    min_longitude: float | None = None
    max_longitude: float | None = None

    def covers(self, point: Coordinates) -> bool:
        bounds = (self.min_latitude, self.max_latitude, self.min_longitude, self.max_longitude)
        if any(value is None for value in bounds):
            return False
        min_latitude, max_latitude, min_longitude, max_longitude = (
            float(value) for value in bounds if value is not None
        )
        return (
            min_latitude <= point.latitude <= max_latitude
            and min_longitude <= point.longitude <= max_longitude
        )
