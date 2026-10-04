"""Community corrections to the radar: "Segnala!" reports, the votes that
confirm or deny them, and star ratings of dog parks.

This is our own data, kept in our own tables: nothing here is ever written
to OpenStreetMap or into the tables that hold open-data imports. People
are identified only by a keyed pseudonym (see `contributor_pseudonym`);
the account id never reaches these tables.
"""

import hashlib
import hmac
import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.radar_places.models import RadarPlace
from packages.shared.errors.base import ValidationError

USER_SOURCE_NAME = "vetapp_users"

ReportKind = Literal["missing", "closed", "duplicate", "wrong_position"]
ReportStatus = Literal["pending", "confirmed", "rejected"]

# A report is dropped once denials outnumber confirmations by this much.
DENIALS_TO_REJECT = 3
# An average of one or two votes is one person's opinion, not a rating.
MIN_RATINGS_TO_SHOW = 3
MAX_PLACE_NAME_LENGTH = 60

# Categories whose address may be someone's home: the reported position is
# coarsened (~500 m) so a report never pins a private address on the map.
HOME_BASED_PLACE_TYPES = frozenset({"hotel", "pet_sitting", "school"})
_COARSE_GRID_DEGREES = 0.005

_DEFAULT_REPORT_NAMES = {"dog_park": "Area cani"}

# Deliberately short: a net for the obvious, not a moderation system.
_BLOCKED_WORDS = frozenset(
    {
        "cazzo",
        "merda",
        "stronzo",
        "stronza",
        "vaffanculo",
        "puttana",
        "troia",
        "bastardo",
        "coglione",
        "minchia",
    }
)


def contributor_pseudonym(user_id: str, *, key: str) -> str:
    """Stable, non-reversible stand-in for an account id. Keyed with a
    server secret that lives outside the database, so the tables alone
    cannot be linked back to accounts, while the server can still find a
    user's contributions (e.g. to delete them with the account)."""
    return hmac.new(key.encode("utf-8"), user_id.encode("utf-8"), hashlib.sha256).hexdigest()


def clean_place_name(name: str | None, *, place_type: str) -> str:
    """The sign over the door and nothing else: no contact details, no
    insults. Dog parks may go unnamed; businesses may not."""
    text = re.sub(r"\s+", " ", name or "").strip()
    if not text:
        default = _DEFAULT_REPORT_NAMES.get(place_type)
        if default is None:
            raise ValidationError("Scrivi il nome dell'attività, come appare sull'insegna.")
        return default
    if len(text) > MAX_PLACE_NAME_LENGTH:
        raise ValidationError(f"Il nome può avere al massimo {MAX_PLACE_NAME_LENGTH} caratteri.")
    lowered = text.lower()
    if (
        re.search(r"\d[\d\s./-]{5,}", text)
        or "@" in text
        or re.search(r"https?:|www\.|\.(it|com|net|org)\b", lowered)
    ):
        raise ValidationError("Nel nome non inserire telefoni, email o siti web.")
    if _BLOCKED_WORDS & set(re.findall(r"[a-zàèéìòù]+", lowered)):
        raise ValidationError("Il nome contiene parole non ammesse.")
    return text


def coarsen_position(latitude: float, longitude: float) -> tuple[float, float]:
    def snap(value: float) -> float:
        return round(round(value / _COARSE_GRID_DEGREES) * _COARSE_GRID_DEGREES, 3)

    return snap(latitude), snap(longitude)


class RadarUserReport(BaseModel):
    id: str = Field(default_factory=new_id)
    kind: ReportKind
    status: ReportStatus = "pending"
    # What is reported: for "missing" the new place itself, for the other
    # kinds the existing place the report is about.
    place_type: str
    name: str
    latitude: float
    longitude: float
    address_label: str | None = None
    target_source: str | None = None
    target_source_id: str | None = None
    reporter_pseudonym: str
    confirmations: int = 0
    denials: int = 0
    created_at: datetime = Field(default_factory=utc_now)
    resolved_at: datetime | None = None

    def resolved_status(self, *, required_confirmations: int) -> ReportStatus:
        """Outcome given the current tallies. Denials subtract from
        confirmations, so a contested report needs a clear majority; a
        report mostly denied is dropped rather than left pending forever."""
        if self.confirmations - self.denials >= required_confirmations:
            return "confirmed"
        if self.denials - self.confirmations >= DENIALS_TO_REJECT:
            return "rejected"
        return "pending"

    def as_place(self) -> RadarPlace:
        """A "missing place" report as a place on the radar."""
        return RadarPlace(
            id=f"{USER_SOURCE_NAME}|{self.id}",
            coverage_key="reports",
            place_type=self.place_type,
            name=self.name,
            latitude=self.latitude,
            longitude=self.longitude,
            address_label=self.address_label,
            source_name=USER_SOURCE_NAME,
            source_external_id=self.id,
            source_fetched_at=self.created_at,
        )


class RadarReportVote(BaseModel):
    report_id: str
    voter_pseudonym: str
    # +1 confirms, -1 denies.
    vote: int
    created_at: datetime = Field(default_factory=utc_now)


class RadarPlaceRating(BaseModel):
    source: str
    source_id: str
    voter_pseudonym: str
    stars: int = Field(ge=1, le=5)
    # Copied from the place so ratings can be read by area like places are.
    latitude: float
    longitude: float
    updated_at: datetime = Field(default_factory=utc_now)


class RadarPlaceOverride(BaseModel):
    """A place taken off the radar for good (confirmed closed or a
    duplicate). Importers skip it by id; reads also drop the same place
    listed by another source, matched by category and position."""

    source: str
    source_id: str
    action: str = "exclude"
    reason: str | None = None
    place_type: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    created_at: datetime = Field(default_factory=utc_now)


_SAME_PLACE_METERS = 30.0


def apply_overrides(
    places: list[RadarPlace], overrides: list[RadarPlaceOverride]
) -> list[RadarPlace]:
    excluded_ids = {(item.source, item.source_id) for item in overrides}
    located = [
        (item.place_type, Coordinates(latitude=item.latitude, longitude=item.longitude))
        for item in overrides
        if item.place_type and item.latitude is not None and item.longitude is not None
    ]

    def is_excluded(place: RadarPlace) -> bool:
        if (place.source_name, place.source_external_id) in excluded_ids:
            return True
        return any(
            place_type == place.place_type
            and haversine_distance_km(place.location, position) * 1000 <= _SAME_PLACE_METERS
            for place_type, position in located
        )

    return [place for place in places if not is_excluded(place)]


def is_publicly_ratable(place: RadarPlace) -> bool:
    """Stars are for public dog parks only: never for a business, and not
    for a park run for paying customers."""
    return (
        place.place_type == "dog_park"
        and place.details.get("fee") != "yes"
        and place.details.get("access") not in {"customers", "private"}
    )
