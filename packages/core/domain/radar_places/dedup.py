"""Merging places that different sources list twice.

The rule of thumb is asymmetric on purpose: showing one clinic twice is an
annoyance, showing two clinics as one (with the wrong phone) is a failure.
Whenever the evidence is not clear the two records stay separate.
"""

import re
import unicodedata
from collections import defaultdict
from collections.abc import Iterable
from urllib.parse import urlsplit

from packages.core.domain.geo.models import haversine_distance_km
from packages.core.domain.radar_places.models import RadarPlace

# Same category this close is the same door.
SAME_SPOT_METERS = 30.0
# Dog parks are areas, not doors: two sources place the same park by
# the centre of slightly different outlines.
DOG_PARK_SAME_METERS = 60.0
# Same category within this distance needs a compatible name.
NEAR_METERS = 120.0
# A shared phone number or website only proves identity nearby: chains
# share one site (and often one switchboard) across every branch in town.
SAME_CONTACT_METERS = 300.0

# Words that describe the kind of business rather than naming it. Two
# clinics both called "Ambulatorio Veterinario <surname>" must be told
# apart by the surname alone.
_GENERIC_WORDS = frozenset(
    {
        "ambulatorio",
        "ambulatori",
        "clinica",
        "cliniche",
        "veterinario",
        "veterinaria",
        "veterinari",
        "veterinarie",
        "studio",
        "medico",
        "associato",
        "associati",
        "centro",
        "ospedale",
        "dott",
        "dottor",
        "dottore",
        "dottoressa",
        "dr",
        "ssa",
        "srl",
        "srls",
        "snc",
        "sas",
        "spa",
        "toelettatura",
        "toeletta",
        "toilettatura",
        "grooming",
        "pet",
        "pets",
        "shop",
        "store",
        "negozio",
        "animali",
        "area",
        "aree",
        "cani",
        "cane",
        "sgambatura",
        "sgambamento",
        "via",
        "parco",
        "giardino",
        "animale",
        "per",
        "gli",
        "dei",
        "del",
        "della",
        "delle",
        "the",
        "and",
    }
)

_FREE_MAIL_AND_SOCIAL_DOMAINS = frozenset(
    {
        "facebook.com",
        "instagram.com",
        "google.com",
        "linktr.ee",
        "wixsite.com",
        "business.site",
        "paginegialle.it",
        "openstreetmap.org",
    }
)


def normalize_phone(phone: str | None) -> str | None:
    """Digits only, without the Italian country prefix, so "+39 02 0000 0001"
    and "0200000001" compare equal. None when too short to identify."""
    digits = re.sub(r"\D", "", phone or "")
    if digits.startswith("0039"):
        digits = digits[4:]
    elif digits.startswith("39") and len(digits) > 10:
        digits = digits[2:]
    return digits if len(digits) >= 6 else None


def website_domain(url: str | None) -> str | None:
    """Registrable-looking host of a website, None for social profiles and
    directories that many unrelated businesses share."""
    if not url:
        return None
    host = urlsplit(url if "//" in url else f"//{url}").hostname or ""
    host = host.lower().removeprefix("www.")
    if not host or any(host == d or host.endswith(f".{d}") for d in _FREE_MAIL_AND_SOCIAL_DOMAINS):
        return None
    return host


def _words(name: str | None) -> list[str]:
    """Words of a name in order: lowercase, unaccented, without the
    generic business words."""
    folded = unicodedata.normalize("NFKD", (name or "").lower())
    plain = "".join(char for char in folded if not unicodedata.combining(char))
    return [token for token in re.findall(r"[a-z0-9]+", plain) if token not in _GENERIC_WORDS]


def name_tokens(name: str | None) -> frozenset[str]:
    """Distinctive words of a name: lowercase, unaccented, generic business
    words and very short words removed."""
    return frozenset(token for token in _words(name) if len(token) > 2)


def names_compatible(first: str | None, second: str | None) -> bool:
    """True when two names plausibly denote the same business: they share
    a distinctive word, or are the same name spaced differently ("Dog
    Cooker" / "Dogcooker", "Wash Dog" / "Washdog"). Names made only of
    generic words ("Ambulatorio Veterinario") say nothing either way and
    are NOT compatible: at 120 m that would merge two different clinics."""
    left, right = name_tokens(first), name_tokens(second)
    if not left or not right:
        return False
    if left & right:
        return True
    left_joined, right_joined = "".join(_words(first)), "".join(_words(second))
    return len(left_joined) >= 6 and left_joined == right_joined


def distance_meters(first: RadarPlace, second: RadarPlace) -> float:
    return haversine_distance_km(first.location, second.location) * 1000


def same_place(first: RadarPlace, second: RadarPlace) -> str | None:
    """Why two records are the same place, or None when they are not (or
    when it is not clear enough to say)."""
    if first.place_type != second.place_type:
        return None
    meters = distance_meters(first, second)
    if meters > SAME_CONTACT_METERS:
        return None

    first_phone, second_phone = normalize_phone(first.phone), normalize_phone(second.phone)
    if first_phone and first_phone == second_phone:
        return "same_phone"
    first_domain, second_domain = (
        website_domain(first.website_url),
        website_domain(second.website_url),
    )
    if first_domain and first_domain == second_domain and meters <= NEAR_METERS:
        return "same_website"
    if first.place_type == "dog_park" and meters <= DOG_PARK_SAME_METERS:
        return "same_spot"
    if meters <= SAME_SPOT_METERS:
        # Two businesses with their own, different names at one address
        # (two practices in a building, two shops side by side) are two
        # places. Same spot only proves identity when the names agree or
        # one of them is just the generic kind ("Ambulatorio Veterinario").
        both_named = name_tokens(first.name) and name_tokens(second.name)
        if both_named and not names_compatible(first.name, second.name):
            return None
        return "same_spot"
    if meters <= NEAR_METERS and names_compatible(first.name, second.name):
        return "near_same_name"
    return None


def _completeness(place: RadarPlace) -> int:
    return (
        (2 if place.phone else 0)
        + (1 if place.opening_hours else 0)
        + (1 if place.website_url else 0)
        + (1 if place.address_label else 0)
        + (1 if place.details else 0)
    )


def _grid_key(place: RadarPlace) -> tuple[int, int]:
    # ~330 m cells: every candidate within SAME_CONTACT_METERS of a place
    # lies in its cell or one of the eight around it.
    return (int(place.latitude / 0.003), int(place.longitude / 0.003))


def merge_radar_places(
    first: Iterable[RadarPlace], second: Iterable[RadarPlace]
) -> list[RadarPlace]:
    """Union of two sources with duplicates collapsed.

    A place found in both is returned once, as the record of the source
    that knows more about it (ties go to `first`), untouched except for
    `confirmed_by` naming the other source. Data is never blended across
    sources: a phone number from one and opening hours from the other
    would look authoritative while being unverified guesswork."""
    kept = list(first)
    grid: dict[tuple[int, int], list[int]] = defaultdict(list)
    for index, place in enumerate(kept):
        grid[_grid_key(place)].append(index)

    result = list(kept)
    for candidate in second:
        row, column = _grid_key(candidate)
        match_index = next(
            (
                index
                for d_row in (-1, 0, 1)
                for d_column in (-1, 0, 1)
                for index in grid.get((row + d_row, column + d_column), ())
                if same_place(result[index], candidate) is not None
            ),
            None,
        )
        if match_index is None:
            grid[(row, column)].append(len(result))
            result.append(candidate)
            continue

        existing = result[match_index]
        if _completeness(candidate) > _completeness(existing):
            existing, candidate = candidate, existing
        confirmed_by = sorted(
            {*existing.confirmed_by, candidate.source_name, *candidate.confirmed_by}
        )
        confirmed_by = [name for name in confirmed_by if name != existing.source_name]
        result[match_index] = existing.model_copy(update={"confirmed_by": confirmed_by})
    return result
