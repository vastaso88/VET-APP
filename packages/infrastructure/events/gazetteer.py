"""Town coordinates for the curated events, from a local open-licence table.

An event without ``latitude``/``longitude`` is never shown to the owners just over the border
(``packages/core/domain/events/abroad.py``). Every curated event already names its town, so the
importer gives it the coordinates of that town from the tables in ``scripts/events/gazetteer/``
(one ``<COUNTRY>.tsv`` per country, built offline by ``scripts/events/build_gazetteer.py``).

No web request and no geocoding service: a town is matched by name inside its province (Italy,
``province_code``) or its region (the other countries, ``region`` spelled as in
``packages/core/domain/events/regions.py``). Accents, case and punctuation do not matter. A name
that is not in the table, or that matches several places, leaves the event without coordinates
and says so: nothing is guessed. Coordinates written in the JSON always win.

The coordinates are the town's, not the venue's: close enough for a 30 km radius.
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, replace
from pathlib import Path

from packages.core.domain.events.regions import DEFAULT_COUNTRY
from packages.core.domain.geo.models import Coordinates
from packages.infrastructure.events.curated_events import CuratedEvent

TABLE_COLUMNS = ("name", "province", "region", "latitude", "longitude", "seat")

_NOT_A_LETTER = re.compile(r"[\W_]+")


def normalize_place_name(text: str) -> str:
    """The lookup key: "Città di Castello", "citta  di-castello" and "CITTÀ DI CASTELLO" match."""
    decomposed = unicodedata.normalize("NFKD", text.casefold())
    plain = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return " ".join(_NOT_A_LETTER.sub(" ", plain).split())


def name_variants(name: str) -> set[str]:
    """Lookup keys of a name; a bilingual one answers to each language: "Aosta / Aoste",
    "Bolzano - Bozen", "Igrèsias/Iglesias"."""
    parts = name.replace(" - ", "/").split("/")
    keys = {normalize_place_name(name), *(normalize_place_name(part) for part in parts)}
    return {key for key in keys if key}


@dataclass(frozen=True)
class Town:
    name: str
    latitude: float
    longitude: float
    # Italian province abbreviation ("MO"); None elsewhere.
    province: str | None = None
    # Region in the app's spelling (regions.py); None when the source has none.
    region: str | None = None
    # Seat of a municipality (or above): preferred over a hamlet with the same name.
    seat: bool = False


@dataclass(frozen=True)
class Lookup:
    town: Town | None
    reason: str


class Gazetteer:
    def __init__(self, towns_by_country: Mapping[str, Iterable[Town]]) -> None:
        self._index: dict[tuple[str, str], list[Town]] = {}
        self._count = 0
        for country, towns in towns_by_country.items():
            for town in towns:
                self._count += 1
                for name in name_variants(town.name):
                    self._index.setdefault((country.upper(), name), []).append(town)
        self.countries = frozenset(country for country, _ in self._index)

    def __len__(self) -> int:
        return self._count

    def locate(
        self,
        *,
        country: str,
        city: str,
        province_code: str | None = None,
        region: str | None = None,
    ) -> Lookup:
        country = country.upper()
        if country not in self.countries:
            return Lookup(None, f"nessuna tabella dei comuni per il paese {country}")
        candidates = self._index.get((country, normalize_place_name(city)), [])
        if not candidates:
            return Lookup(None, "comune non trovato nella tabella")

        how = ""
        by_province = False
        if country == DEFAULT_COUNTRY and province_code:
            matches = [town for town in candidates if town.province == province_code]
            how = f"provincia {province_code}"
            by_province = bool(matches)
            if not matches and region:
                # The source may have no abbreviation for the town's province (Sardinia, 2025
                # reform): a municipality seat with that name and no province, unique in the
                # region, is as good. Never a hamlet, never a town whose known province says
                # otherwise.
                matches = [
                    town
                    for town in candidates
                    if town.region == region and town.seat and town.province is None
                ]
                how = f"regione {region} (provincia {province_code} non trovata)"
        elif region:
            matches = [town for town in candidates if town.region == region]
            how = f"regione {region}"
        else:
            return Lookup(None, "manca la provincia o la regione per distinguere il comune")

        if not matches:
            return Lookup(None, f"comune non trovato in {how}")
        if len(matches) > 1:
            # Inside one province the comune wins over a hamlet with its name. Inside a whole
            # region two places with one name are two towns (Newport, Wales): ambiguous.
            seats = [town for town in matches if town.seat] if by_province else []
            if len(seats) != 1:
                return Lookup(None, f"nome ambiguo: {len(matches)} luoghi in {how}")
            matches = seats
        return Lookup(matches[0], how)


def load_gazetteer(directory: Path) -> Gazetteer:
    """Reads every ``<COUNTRY>.tsv`` in ``directory``; a missing folder is an empty table.
    Lines starting with ``#`` are comments (the attribution the licence asks for)."""
    towns_by_country: dict[str, list[Town]] = {}
    if not directory.is_dir():
        return Gazetteer({})
    for path in sorted(directory.glob("*.tsv")):
        towns_by_country[path.stem.upper()] = list(_read_table(path))
    return Gazetteer(towns_by_country)


def _read_table(path: Path) -> Iterable[Town]:
    header_seen = False
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if not header_seen:
            if tuple(fields) != TABLE_COLUMNS:
                raise ValueError(f"{path.name}: intestazione attesa {TABLE_COLUMNS}")
            header_seen = True
            continue
        if len(fields) != len(TABLE_COLUMNS):
            raise ValueError(f"{path.name}:{number}: attese {len(TABLE_COLUMNS)} colonne")
        name, province, region, latitude, longitude, seat = fields
        yield Town(
            name=name,
            province=province or None,
            region=region or None,
            latitude=float(latitude),
            longitude=float(longitude),
            seat=seat == "1",
        )


def write_table(path: Path, towns: Sequence[Town], *, header_comments: Sequence[str]) -> None:
    """The committed table: sorted, coordinates rounded to 3 decimals (about 100 m)."""
    lines = [f"# {comment}" for comment in header_comments]
    lines.append("\t".join(TABLE_COLUMNS))
    for town in sorted(towns, key=lambda t: (normalize_place_name(t.name), t.province or "")):
        lines.append(
            "\t".join(
                (
                    town.name,
                    town.province or "",
                    town.region or "",
                    f"{town.latitude:.3f}",
                    f"{town.longitude:.3f}",
                    "1" if town.seat else "0",
                )
            )
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def fill_missing_places(
    events: Sequence[CuratedEvent], gazetteer: Gazetteer
) -> tuple[list[CuratedEvent], list[str]]:
    """Gives each event without coordinates those of its town. Returns the events (the same
    objects when nothing changes) and one readable line per event."""
    filled: list[CuratedEvent] = []
    notes: list[str] = []
    for event in events:
        if event.place is not None:
            notes.append(f"{event.slug}: coordinate già nel file, restano quelle")
            filled.append(event)
            continue
        if not event.city:
            notes.append(f"{event.slug}: nessuna città nel file, nessuna coordinata")
            filled.append(event)
            continue
        lookup = gazetteer.locate(
            country=event.country,
            city=event.city,
            province_code=event.province_code,
            region=event.region,
        )
        if lookup.town is None:
            notes.append(f"{event.slug}: nessuna coordinata per {event.city}: {lookup.reason}")
            filled.append(event)
            continue
        town = lookup.town
        place = Coordinates(latitude=town.latitude, longitude=town.longitude)
        notes.append(
            f"{event.slug}: {event.city} -> {town.name} ({lookup.reason}) "
            f"{town.latitude:.3f}, {town.longitude:.3f}"
        )
        filled.append(replace(event, place=place))
    return filled, notes
