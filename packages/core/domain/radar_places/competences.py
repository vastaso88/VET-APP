"""Exotic-animal competence of veterinary practices ("Esperti in esotici").

A practice is listed under a group only when a verifiable source declares
it, and every competence keeps where it was read and when:

- OpenStreetMap: `veterinary:treats:<animal>=yes` tags on the practice;
- the practice's own name ("Ambulatorio per animali esotici"), only when
  RADAR_EXOTIC_NAME_MATCHING is on (off by default: owner's decision);
- a "Segnala!" claim, shown only after the team checked the practice's own
  public statement and confirmed it by hand
  (scripts/radar/confirm_competence_claim.py).

Nothing here is a judgement by Quokka: the app says so next to every one.
"""

import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now

ExoticGroup = Literal["reptile_amphibian", "bird", "small_mammal", "fish", "other"]
EXOTIC_GROUPS: tuple[str, ...] = ("reptile_amphibian", "bird", "small_mammal", "fish", "other")

# "Exotic animals" with no group named: the practice matches every group,
# and the card says the groups were not stated.
EXOTIC_GENERAL = "exotic_general"

CompetenceBasis = Literal["osm_tag", "name", "confirmed_claim"]

OSM_TREATS_PREFIX = "veterinary:treats:"

# OSM animal values (veterinary:treats:<value>) by group. Dogs, cats and
# farm animals are not exotic and are ignored.
_OSM_ANIMALS: dict[str, str] = {
    **dict.fromkeys(
        ("reptile", "reptiles", "turtle", "tortoise", "snake", "lizard", "amphibian"),
        "reptile_amphibian",
    ),
    **dict.fromkeys(("bird", "birds", "parrot", "parrots", "pigeon"), "bird"),
    **dict.fromkeys(
        (
            "rabbit",
            "rabbits",
            "rodent",
            "rodents",
            "guinea_pig",
            "hamster",
            "rat",
            "mouse",
            "chinchilla",
            "ferret",
            "small_mammal",
            "small_mammals",
        ),
        "small_mammal",
    ),
    **dict.fromkeys(("fish", "aquarium_fish", "koi"), "fish"),
    **dict.fromkeys(("exotic", "exotics", "exotic_animals"), EXOTIC_GENERAL),
}

# Strict words only: a name that merely contains "pesc" (Pescara) or
# "uccell" in a street name must not make a practice an exotics expert.
_NAME_RULES: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"\b(esotic|exotic|non convenzional)|\bnac\b", re.IGNORECASE), EXOTIC_GENERAL),
    (re.compile(r"\b(rettil|erpetolog)", re.IGNORECASE), "reptile_amphibian"),
    (re.compile(r"\b(aviar|ornitolog)", re.IGNORECASE), "bird"),
    (re.compile(r"\b(conigli|roditor|furett)", re.IGNORECASE), "small_mammal"),
    (re.compile(r"\bittiopatolog", re.IGNORECASE), "fish"),
)


class ExoticCompetence(BaseModel):
    group: str
    # Where it was read: a source name ("openstreetmap_overpass", "overture",
    # "vetapp_users") and how (tag, name, confirmed claim).
    source: str
    basis: CompetenceBasis
    read_at: datetime | None = None
    # For a confirmed claim: the practice's own public page that was checked.
    evidence_url: str | None = None


def groups_from_osm_details(details: dict[str, str]) -> list[str]:
    """Groups declared by `veterinary:treats:*=yes` tags kept in a place's
    details (see overpass_places_source._read_details)."""
    groups: list[str] = []
    for key, value in details.items():
        if not key.startswith(OSM_TREATS_PREFIX) or value.strip().lower() != "yes":
            continue
        group = _OSM_ANIMALS.get(key.removeprefix(OSM_TREATS_PREFIX).strip().lower())
        if group and group not in groups:
            groups.append(group)
    return groups


def groups_from_name(name: str) -> list[str]:
    groups: list[str] = []
    for pattern, group in _NAME_RULES:
        if pattern.search(name) and group not in groups:
            groups.append(group)
    return groups


def matches_group(competences: list[ExoticCompetence], group: str | None) -> bool:
    """Whether a practice belongs under [group] (None: any exotic group)."""
    if not competences:
        return False
    if group is None:
        return True
    return any(item.group in {group, EXOTIC_GENERAL} for item in competences)


ClaimEvidenceKind = Literal["website", "sign", "other"]
ClaimStatus = Literal["pending", "confirmed", "rejected"]


class RadarCompetenceClaim(BaseModel):
    """ "Segnala!": "this practice treats exotic animals". Stays pending,
    and invisible, until the team has read the practice's own public
    statement and confirmed it with that page as evidence."""

    id: str = Field(default_factory=new_id)
    target_source: str
    target_source_id: str
    # The practice's own name and position, echoed for the moderation
    # queue: not user-authored text.
    place_name: str
    latitude: float
    longitude: float
    groups: list[str]
    # Where the reporter read it; checked by the team, never shown as proof.
    evidence_kind: ClaimEvidenceKind
    status: ClaimStatus = "pending"
    reporter_pseudonym: str
    created_at: datetime = Field(default_factory=utc_now)
    resolved_at: datetime | None = None
    # Set by the team on confirmation: the practice's page that says so.
    evidence_url: str | None = None
    resolution_note: str | None = None

    def as_competences(self) -> list[ExoticCompetence]:
        if self.status != "confirmed":
            return []
        return [
            ExoticCompetence(
                group=group,
                source="vetapp_users",
                basis="confirmed_claim",
                read_at=self.resolved_at,
                evidence_url=self.evidence_url,
            )
            for group in self.groups
        ]


def competences_of(
    place_type: str,
    *,
    source_name: str,
    name: str,
    details: dict[str, str],
    read_at: datetime | None,
    name_matching: bool,
    confirmed_claims: list[RadarCompetenceClaim] = (),  # type: ignore[assignment]
) -> list[ExoticCompetence]:
    """Every declared competence of one place, each with its own source."""
    if place_type != "veterinary":
        return []
    found = [
        ExoticCompetence(group=group, source=source_name, basis="osm_tag", read_at=read_at)
        for group in groups_from_osm_details(details)
    ]
    if name_matching:
        found += [
            ExoticCompetence(group=group, source=source_name, basis="name", read_at=read_at)
            for group in groups_from_name(name)
        ]
    for claim in confirmed_claims:
        found += claim.as_competences()
    return found
