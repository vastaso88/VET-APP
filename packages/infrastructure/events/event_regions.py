"""Regions of the countries the curated events can be in.

An event's ``region`` is checked against the table of its ``country``: a typo,
or a region of another country, never reaches the database. The names are
written the way the country writes them, because the app shows exactly this
text in its region filter. One entry per country the app has a language
variant for (docs/i18n/NOTIZIE_EVENTI_MERCATINO.md).
"""

from __future__ import annotations

ITALIAN_REGIONS = frozenset(
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

_US_STATES = frozenset(
    {
        "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
        "Connecticut", "Delaware", "District of Columbia", "Florida", "Georgia",
        "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky",
        "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota",
        "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada", "New Hampshire",
        "New Jersey", "New Mexico", "New York", "North Carolina", "North Dakota",
        "Ohio", "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
        "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", "Virginia",
        "Washington", "West Virginia", "Wisconsin", "Wyoming",
    }
)  # fmt: skip

_AU_STATES = frozenset(
    {
        "New South Wales", "Victoria", "Queensland", "Western Australia",
        "South Australia", "Tasmania", "Australian Capital Territory",
        "Northern Territory",
    }
)  # fmt: skip

_DE_LAENDER = frozenset(
    {
        "Baden-Württemberg", "Bayern", "Berlin", "Brandenburg", "Bremen", "Hamburg",
        "Hessen", "Mecklenburg-Vorpommern", "Niedersachsen", "Nordrhein-Westfalen",
        "Rheinland-Pfalz", "Saarland", "Sachsen", "Sachsen-Anhalt",
        "Schleswig-Holstein", "Thüringen",
    }
)  # fmt: skip

_FR_REGIONS = frozenset(
    {
        "Auvergne-Rhône-Alpes", "Bourgogne-Franche-Comté", "Bretagne",
        "Centre-Val de Loire", "Corse", "Grand Est", "Hauts-de-France", "Île-de-France",
        "Normandie", "Nouvelle-Aquitaine", "Occitanie", "Pays de la Loire",
        "Provence-Alpes-Côte d'Azur",
    }
)  # fmt: skip

_ES_COMUNIDADES = frozenset(
    {
        "Andalucía", "Aragón", "Principado de Asturias", "Illes Balears", "Canarias",
        "Cantabria", "Castilla-La Mancha", "Castilla y León", "Cataluña",
        "Comunitat Valenciana", "Extremadura", "Galicia", "Comunidad de Madrid",
        "Región de Murcia", "Comunidad Foral de Navarra", "País Vasco", "La Rioja",
        "Ceuta", "Melilla",
    }
)  # fmt: skip

REGIONS_BY_COUNTRY: dict[str, frozenset[str]] = {
    "IT": ITALIAN_REGIONS,
    "GB": frozenset({"England", "Scotland", "Wales", "Northern Ireland"}),
    "US": _US_STATES,
    "AU": _AU_STATES,
    "DE": _DE_LAENDER,
    "FR": _FR_REGIONS,
    "ES": _ES_COMUNIDADES,
}

# Events written before the country existed are Italian.
DEFAULT_COUNTRY = "IT"
COUNTRIES = frozenset(REGIONS_BY_COUNTRY)
