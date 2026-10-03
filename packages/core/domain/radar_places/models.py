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
]

# Fields that only matter while importing (raw provider element, the
# requesting owner) and are deliberately not persisted in the shared cache.
RADAR_PLACE_TRANSIENT_FIELDS = frozenset(
    {"owner_id", "external_record_id", "source_payload", "freshness_status"}
)


class RadarPlace(BaseModel):
    """A pet-related business or service imported from an external place
    source (OpenStreetMap today) and cached by coverage cell."""

    id: str = ""
    owner_id: str = ""
    coverage_key: str
    place_type: str
    subtype: str | None = None
    name: str
    summary: str | None = None
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

    @model_validator(mode="after")
    def _assign_id(self) -> "RadarPlace":
        if not self.id:
            self.id = f"{self.coverage_key}|{self.source_name}|{self.source_external_id}"
        return self

    @property
    def location(self) -> Coordinates:
        return Coordinates(latitude=self.latitude, longitude=self.longitude)
