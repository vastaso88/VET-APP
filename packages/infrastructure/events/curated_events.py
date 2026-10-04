"""Validation and loading of the hand-curated events file(s).

Events of the "Eventi" section come from `data/events/curated/*.json`, written
by a person who checked date and link on the organizer's official site. This
module is the gate between those files and the database: it refuses anything
the project's rules (docs/features/events_engine.md) do not allow, so a typo or
a shortcut can never reach production. `scripts/events/import_curated.py` is
the thin command-line wrapper around it.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

EVENT_TYPES = frozenset(
    {
        "pet_fair",
        "dog_show",
        "breed_gathering",
        "cat_show",
        "work_trial",
        "dog_sport",
        "adoption_day",
        "shelter_open_day",
        "microchip_day",
        "vaccination_campaign",
        "group_walk",
        "course_seminar",
        "market",
        "charity_event",
        "aquarium_expo",
        "reptile_expo",
        "bird_show",
        "equestrian",
        "other",
    }
)

LEVELS = ("local", "provincial", "regional", "national", "international")

# How the level was decided (docs/features/events_engine.md, section 2.2).
LEVEL_BASES = frozenset(
    {
        "official_qualification",
        "federation_title",
        "declared_metrics",
        "organizer_claim",
        "curated",
        "default",
    }
)

# Rule 2 of the document: an organizer calling its own event "international" is
# marketing, not a document - without a documented basis the level never goes
# above "regional", and "default" means "local" by definition.
_LEVEL_CAP_WITHOUT_DOCUMENT = {"organizer_claim": "regional", "default": "local"}

STATUSES = frozenset({"published", "cancelled", "postponed", "rejected", "draft"})

REGIONS = frozenset(
    {
        "Abruzzo",
        "Basilicata",
        "Calabria",
        "Campania",
        "Emilia-Romagna",
        "Friuli-Venezia Giulia",
        "Lazio",
        "Liguria",
        "Lombardia",
        "Marche",
        "Molise",
        "Piemonte",
        "Puglia",
        "Sardegna",
        "Sicilia",
        "Toscana",
        "Trentino-Alto Adige",
        "Umbria",
        "Valle d'Aosta",
        "Veneto",
    }
)

# Social networks and commercial aggregators: never an acceptable source
# (terms of use, no reuse, no way to tell who wrote what).
_BLOCKED_SOURCE_DOMAINS = (
    "facebook.com",
    "fb.com",
    "instagram.com",
    "eventbrite.",
    "meetup.com",
    "tiktok.com",
    "x.com",
    "twitter.com",
)

_SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
_PROVINCE = re.compile(r"^[A-Z]{2}$")
_EMAIL = re.compile(r"\S+@\S+")
# Seven or more digits, allowing the usual separators: a telephone number.
_PHONE = re.compile(r"(?:\+?\d[\s./-]?){7,}")

DEFAULT_LICENSE = "fatti pubblici verificati sul sito dell'organizzatore"
SOURCE_KEY = "curated"


class CuratedEventError(ValueError):
    """A curated event that must not be imported, with the reason in clear."""


@dataclass(frozen=True)
class CuratedEvent:
    slug: str
    title: str
    event_type: str
    level: str
    level_basis: str
    starts_on: date
    ends_on: date
    source_url: str
    verified_on: date
    status: str
    region: str | None = None
    city: str | None = None
    province_code: str | None = None
    venue_name: str | None = None
    organizer_name: str | None = None
    description: str | None = None


def _text(raw: dict[str, Any], key: str, *, required: bool = False) -> str | None:
    value = raw.get(key)
    if value is None or (isinstance(value, str) and not value.strip()):
        if required:
            raise CuratedEventError(f"campo obbligatorio mancante: {key}")
        return None
    if not isinstance(value, str):
        raise CuratedEventError(f"{key} deve essere un testo")
    return value.strip()


def _date(raw: dict[str, Any], key: str) -> date:
    value = _text(raw, key, required=True)
    assert value is not None
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise CuratedEventError(f"{key} non è una data ISO (AAAA-MM-GG): {value!r}") from exc


def _reject_personal_data(key: str, value: str | None) -> None:
    if value is None:
        return
    if _EMAIL.search(value) or _PHONE.search(value):
        raise CuratedEventError(
            f"{key} contiene un indirizzo email o un numero di telefono: "
            "nel repository pubblico vanno solo fatti sull'ente, mai contatti"
        )


def _validate_source_url(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        raise CuratedEventError(f"source_url non è un indirizzo http(s) valido: {url!r}")
    host = parsed.hostname.lower()
    if any(blocked in host for blocked in _BLOCKED_SOURCE_DOMAINS):
        raise CuratedEventError(
            f"source_url punta a {host}: social network e aggregatori non sono fonti ammesse; "
            "serve la pagina ufficiale dell'organizzatore"
        )


def validate_curated_event(raw: object, *, today: date | None = None) -> CuratedEvent:
    """Turns one JSON object into a `CuratedEvent` or raises `CuratedEventError`."""
    if not isinstance(raw, dict):
        raise CuratedEventError("ogni evento deve essere un oggetto JSON")
    reference_day = today or datetime.now(UTC).date()

    slug = _text(raw, "slug", required=True)
    title = _text(raw, "title", required=True)
    event_type = _text(raw, "event_type", required=True)
    level = _text(raw, "level", required=True)
    level_basis = _text(raw, "level_basis", required=True)
    source_url = _text(raw, "source_url", required=True)
    assert slug and title and event_type and level and level_basis and source_url

    if not _SLUG.match(slug):
        raise CuratedEventError(f"slug non valido (minuscole, cifre e trattini): {slug!r}")
    if event_type not in EVENT_TYPES:
        raise CuratedEventError(f"event_type sconosciuto: {event_type!r}")
    if level not in LEVELS:
        raise CuratedEventError(f"level sconosciuto: {level!r}")
    if level_basis not in LEVEL_BASES:
        raise CuratedEventError(f"level_basis sconosciuto: {level_basis!r}")
    cap = _LEVEL_CAP_WITHOUT_DOCUMENT.get(level_basis)
    if cap is not None and LEVELS.index(level) > LEVELS.index(cap):
        raise CuratedEventError(
            f"level {level!r} non è ammesso con level_basis {level_basis!r} "
            f"(senza un documento il massimo è {cap!r})"
        )

    starts_on = _date(raw, "starts_on")
    ends_on = _date(raw, "ends_on")
    if ends_on < starts_on:
        raise CuratedEventError("ends_on precede starts_on")

    verified_on = _date(raw, "verified_on")
    if verified_on > reference_day:
        raise CuratedEventError("verified_on è nel futuro")

    status = _text(raw, "status") or "published"
    if status not in STATUSES:
        raise CuratedEventError(f"status sconosciuto: {status!r}")

    _validate_source_url(source_url)

    region = _text(raw, "region")
    if region is not None and region not in REGIONS:
        raise CuratedEventError(f"region non è una regione italiana nota: {region!r}")
    province_code = _text(raw, "province_code")
    if province_code is not None and not _PROVINCE.match(province_code):
        raise CuratedEventError(
            f"province_code deve essere una sigla di due lettere maiuscole: {province_code!r}"
        )
    city = _text(raw, "city")
    if status in ("published", "cancelled", "postponed") and not (city or region):
        raise CuratedEventError("serve almeno city o region per mostrare dove si svolge")

    venue_name = _text(raw, "venue_name")
    organizer_name = _text(raw, "organizer_name")
    description = _text(raw, "description")
    for key, value in (
        ("title", title),
        ("venue_name", venue_name),
        ("organizer_name", organizer_name),
        ("description", description),
    ):
        _reject_personal_data(key, value)

    return CuratedEvent(
        slug=slug,
        title=title,
        event_type=event_type,
        level=level,
        level_basis=level_basis,
        starts_on=starts_on,
        ends_on=ends_on,
        source_url=source_url,
        verified_on=verified_on,
        status=status,
        region=region,
        city=city,
        province_code=province_code,
        venue_name=venue_name,
        organizer_name=organizer_name,
        description=description,
    )


def curated_event_to_row(event: CuratedEvent, *, now_iso: str) -> dict[str, Any]:
    """The `events` row for an event. The verification date is the curator's
    (`verified_on`, the day the date and link were checked on the official
    site), not the day the import ran."""
    return {
        "slug": event.slug,
        "title": event.title,
        "description": event.description,
        "event_type": event.event_type,
        "level": event.level,
        "level_basis": event.level_basis,
        "audience": "public",
        "starts_on": event.starts_on.isoformat(),
        "ends_on": event.ends_on.isoformat(),
        "city": event.city,
        "province_code": event.province_code,
        "region": event.region,
        "venue_name": event.venue_name,
        "organizer_name": event.organizer_name,
        "source_url": event.source_url,
        "source": SOURCE_KEY,
        "license": DEFAULT_LICENSE,
        "status": event.status,
        "verification_status": "verified",
        "last_verified_at": datetime.combine(
            event.verified_on, datetime.min.time(), tzinfo=UTC
        ).isoformat(),
        "updated_at": now_iso,
    }


def load_curated_events(
    directory: Path, *, today: date | None = None
) -> tuple[list[CuratedEvent], list[str]]:
    """Reads every `*.json` file in `directory` (each an object with an
    `events` list, or a bare list). Returns the valid events and a readable
    problem per rejected event: one bad entry never hides the others, but the
    caller decides whether any problem stops the import."""
    events: list[CuratedEvent] = []
    problems: list[str] = []
    seen_slugs: dict[str, str] = {}

    for path in sorted(directory.glob("*.json")):
        try:
            document = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            problems.append(f"{path.name}: file illeggibile ({exc})")
            continue

        entries = document.get("events") if isinstance(document, dict) else document
        if not isinstance(entries, list):
            problems.append(f"{path.name}: atteso un elenco di eventi (chiave 'events')")
            continue

        for index, raw in enumerate(entries, start=1):
            label = f"{path.name} #{index}"
            try:
                event = validate_curated_event(raw, today=today)
            except CuratedEventError as exc:
                problems.append(f"{label}: {exc}")
                continue
            if event.slug in seen_slugs:
                problems.append(
                    f"{label}: slug duplicato (già in {seen_slugs[event.slug]}): {event.slug}"
                )
                continue
            seen_slugs[event.slug] = label
            events.append(event)

    return events, problems
