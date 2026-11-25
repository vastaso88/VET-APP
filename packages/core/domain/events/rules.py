"""Rules shared by every way an event can enter the "Eventi" section: the
hand-curated files, the feed importers and the suggestions of the users.
"""

import re

from packages.core.domain.events.regions import DEFAULT_COUNTRY

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

# Social networks and commercial aggregators: never an acceptable source
# (terms of use, no reuse, no way to tell who wrote what).
BLOCKED_SOURCE_DOMAINS = (
    "facebook.com",
    "fb.com",
    "instagram.com",
    "eventbrite.",
    "meetup.com",
    "tiktok.com",
    "x.com",
    "twitter.com",
)

# Italy: the two letters of the province. Elsewhere the code of the state, Land, département or
# province, one to three letters or digits ("NSW", "BY", "75", "2A").
_ITALIAN_PROVINCE = re.compile(r"[A-Z]{2}")
_SUBDIVISION = re.compile(r"[A-Z0-9]{1,3}")

_EMAIL = re.compile(r"\S+@\S+")
# Seven or more digits, allowing the usual separators: a telephone number.
_PHONE = re.compile(r"(?:\+?\d[\s./-]?){7,}")


def is_valid_subdivision(country: str, code: str) -> bool:
    pattern = _ITALIAN_PROVINCE if country == DEFAULT_COUNTRY else _SUBDIVISION
    return pattern.fullmatch(code) is not None


def contains_personal_data(value: str | None) -> bool:
    """An email address or a telephone number: never allowed in event text."""
    return value is not None and bool(_EMAIL.search(value) or _PHONE.search(value))
