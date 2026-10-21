"""Rules shared by every way an event can enter the "Eventi" section: the
hand-curated files, the feed importers and the suggestions of the users.
"""

import re

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

_EMAIL = re.compile(r"\S+@\S+")
# Seven or more digits, allowing the usual separators: a telephone number.
_PHONE = re.compile(r"(?:\+?\d[\s./-]?){7,}")


def contains_personal_data(value: str | None) -> bool:
    """An email address or a telephone number: never allowed in event text."""
    return value is not None and bool(_EMAIL.search(value) or _PHONE.search(value))
