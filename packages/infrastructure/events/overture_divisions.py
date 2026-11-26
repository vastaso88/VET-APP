"""Turns Overture Maps "divisions" into the town tables of ``gazetteer.py``.

The builder (``scripts/events/build_gazetteer.py``) reads, for one country, the ``division`` rows
of subtype ``locality`` from the public Overture release with DuckDB, the same way and with the
same request log as the radar (``scripts/radar/import_overture_places.py``). Each row has a name,
a point, the ISO 3166-2 code of its region and a hierarchy (country, region, county, locality...).

- A locality whose parent is not another locality is a municipality (in Italy a comune; its
  hamlets hang below it): it is a "seat" and wins over a hamlet with the same name.
- The region is the app's name for the ISO code (``packages/core/domain/geo/countries.py``).
- In Italy the province abbreviation comes from the county's name (``ITALIAN_PROVINCES``).

The divisions are derived from OpenStreetMap: ODbL 1.0. The tables are a derived database under
the same licence, with the attribution in their header.
"""

from __future__ import annotations

from collections import Counter
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from typing import Any

from packages.core.domain.events.regions import DEFAULT_COUNTRY, regions_of
from packages.core.domain.geo.countries import RadarCountry
from packages.infrastructure.events.gazetteer import Town, normalize_place_name

ATTRIBUTION_LINES = (
    "© OpenStreetMap contributors, Overture Maps Foundation.",
    "Fonte: Overture Maps, tema «divisions» (dati da OpenStreetMap), licenza ODbL 1.0 "
    "(https://opendatacommons.org/licenses/odbl/1-0/). Questa tabella è un database derivato, "
    "rilasciato con la stessa licenza.",
    "Modifiche: solo le località, colonne ridotte, coordinate arrotondate a 3 decimali, "
    "regioni e sigle di provincia scritte come nell'app.",
    "Generato da scripts/events/build_gazetteer.py: non modificare a mano.",
)

DIVISIONS_PATH = "s3://overturemaps-us-west-2/release/{release}/theme=divisions/type=division/*"

# Where the radar's region names differ from the app's (regions.py).
_REGION_NAME_OVERRIDES = {
    "ES": {
        "Asturias": "Principado de Asturias",
        "Madrid": "Comunidad de Madrid",
        "Murcia": "Región de Murcia",
        "Navarra": "Comunidad Foral de Navarra",
    }
}

# Region codes Overture writes differently from the radar's table (Corsica: FR-20R in
# Overture, FR-COR in packages/core/domain/geo/countries.py).
_REGION_CODE_ALIASES = {"FR": {"FR-20R": "FR-COR"}}

# Italian provinces and metropolitan cities: abbreviation -> names the county may carry
# (OpenStreetMap writes the name of the province, sometimes in two languages). The Sardinian
# provinces of the 2025 reform (Gallura Nord-Est Sardegna, Medio Campidano, Ogliastra, Sulcis
# Iglesiente) are not here: no verified abbreviation yet. Their towns keep the region, and the
# lookup falls back to it for a municipality unique in Sardinia.
ITALIAN_PROVINCES: dict[str, tuple[str, ...]] = {
    "AG": ("Agrigento",), "AL": ("Alessandria",), "AN": ("Ancona",), "AO": ("Aosta",),
    "AP": ("Ascoli Piceno",), "AQ": ("L'Aquila",), "AR": ("Arezzo",), "AT": ("Asti",),
    "AV": ("Avellino",), "BA": ("Bari",), "BG": ("Bergamo",), "BI": ("Biella",),
    "BL": ("Belluno",), "BN": ("Benevento",), "BO": ("Bologna",), "BR": ("Brindisi",),
    "BS": ("Brescia",), "BT": ("Barletta-Andria-Trani",), "BZ": ("Bolzano", "Bozen"),
    "CA": ("Cagliari",), "CB": ("Campobasso",), "CE": ("Caserta",), "CH": ("Chieti",),
    "CL": ("Caltanissetta",), "CN": ("Cuneo",), "CO": ("Como",), "CR": ("Cremona",),
    "CS": ("Cosenza",), "CT": ("Catania",), "CZ": ("Catanzaro",), "EN": ("Enna",),
    "FC": ("Forlì-Cesena",), "FE": ("Ferrara",), "FG": ("Foggia",), "FI": ("Firenze",),
    "FM": ("Fermo",), "FR": ("Frosinone",), "GE": ("Genova",), "GO": ("Gorizia",),
    "GR": ("Grosseto",), "IM": ("Imperia",), "IS": ("Isernia",), "KR": ("Crotone",),
    "LC": ("Lecco",), "LE": ("Lecce",), "LI": ("Livorno",), "LO": ("Lodi",),
    "LT": ("Latina",), "LU": ("Lucca",), "MB": ("Monza e della Brianza", "Monza e Brianza"),
    "MC": ("Macerata",), "ME": ("Messina",), "MI": ("Milano",), "MN": ("Mantova",),
    "MO": ("Modena",), "MS": ("Massa-Carrara", "Massa e Carrara"), "MT": ("Matera",),
    "NA": ("Napoli",), "NO": ("Novara",), "NU": ("Nuoro",), "OR": ("Oristano",),
    "PA": ("Palermo",), "PC": ("Piacenza",), "PD": ("Padova",), "PE": ("Pescara",),
    "PG": ("Perugia",), "PI": ("Pisa",), "PN": ("Pordenone",), "PO": ("Prato",),
    "PR": ("Parma",), "PT": ("Pistoia",), "PU": ("Pesaro e Urbino",), "PV": ("Pavia",),
    "PZ": ("Potenza",), "RA": ("Ravenna",), "RC": ("Reggio Calabria", "Reggio di Calabria"),
    "RE": ("Reggio Emilia", "Reggio nell'Emilia"), "RG": ("Ragusa",), "RI": ("Rieti",),
    "RM": ("Roma", "Roma Capitale"), "RN": ("Rimini",), "RO": ("Rovigo",), "SA": ("Salerno",),
    "SI": ("Siena",), "SO": ("Sondrio",), "SP": ("La Spezia",), "SR": ("Siracusa",),
    "SS": ("Sassari",), "SU": ("Sud Sardegna",), "SV": ("Savona",), "TA": ("Taranto",),
    "TE": ("Teramo",), "TN": ("Trento", "Trient"), "TO": ("Torino",), "TP": ("Trapani",),
    "TR": ("Terni",), "TS": ("Trieste",), "TV": ("Treviso",), "UD": ("Udine",),
    "VA": ("Varese",), "VB": ("Verbano-Cusio-Ossola",), "VC": ("Vercelli",),
    "VE": ("Venezia",), "VI": ("Vicenza",), "VR": ("Verona",), "VT": ("Viterbo",),
    "VV": ("Vibo Valentia",),
}  # fmt: skip

# Words around the name of a province in OpenStreetMap ("Città metropolitana di Milano",
# "Provincia di Modena", "Ente di decentramento regionale di Udine", "Libero consorzio
# comunale di Ragusa"): removed before the lookup.
_PROVINCE_PREFIXES = (
    "citta metropolitana di ",
    "provincia autonoma di ",
    "provincia di ",
    "provincia dell ",
    "provincia del ",
    "ente di decentramento regionale di ",
    "libero consorzio comunale di ",
)

_PROVINCE_BY_NAME = {
    normalize_place_name(name): code for code, names in ITALIAN_PROVINCES.items() for name in names
}


def province_code(county_name: str | None) -> str | None:
    """ "Città metropolitana di Milano" -> "MI"; "Bolzano - Alto Adige / Bozen - Südtirol" ->
    "BZ"; an unknown name -> None (the town keeps only its region)."""
    if not county_name:
        return None
    for part in county_name.replace(" - ", "/").split("/"):
        key = normalize_place_name(part)
        for prefix in _PROVINCE_PREFIXES:
            if key.startswith(prefix):
                key = key[len(prefix) :]
                break
        if key in _PROVINCE_BY_NAME:
            return _PROVINCE_BY_NAME[key]
    return None


def app_region_names(country: RadarCountry) -> dict[str, str]:
    """{ISO 3166-2 code: region as regions.py writes it} for one country."""
    overrides = _REGION_NAME_OVERRIDES.get(country.code, {})
    names = {region.code: overrides.get(region.name, region.name) for region in country.regions}
    for overture_code, radar_code in _REGION_CODE_ALIASES.get(country.code, {}).items():
        if radar_code in names:
            names[overture_code] = names[radar_code]
    return names


def missing_app_regions(country: RadarCountry) -> list[str]:
    """Regions of the app that no ISO code produces (must be none)."""
    return sorted(regions_of(country.code) - set(app_region_names(country).values()))


def build_localities_query(release: str, country: RadarCountry) -> str:
    """The localities of one country. The rectangles let DuckDB skip most of the planet's
    files; the country code then drops the neighbours inside them. Hamlets (a locality inside
    another locality) are left out unless they are towns or cities: the table stays small."""
    inside = " OR ".join(
        f"(bbox.xmin BETWEEN {box.min_longitude} AND {box.max_longitude} "
        f"AND bbox.ymin BETWEEN {box.min_latitude} AND {box.max_latitude})"
        for box in country.bounds
    )
    path = DIVISIONS_PATH.format(release=release)
    return f"""
        SELECT names.primary AS name,
               class,
               region AS region_code,
               bbox.xmin AS longitude,
               bbox.ymin AS latitude,
               hierarchies[1] AS hierarchy,
               sources[1].license AS license
        FROM read_parquet('{path}', hive_partitioning = 1)
        WHERE ({inside})
          AND country = '{country.code}'
          AND subtype = 'locality'
          AND (
              len(hierarchies[1]) < 2
              OR hierarchies[1][len(hierarchies[1]) - 1].subtype <> 'locality'
              OR class IN ('city', 'town')
          )
    """


@dataclass
class Conversion:
    towns: list[Town] = field(default_factory=list)
    licenses: Counter[str] = field(default_factory=Counter)
    # County names that gave no province abbreviation (Italy), with how many towns.
    unknown_counties: Counter[str] = field(default_factory=Counter)
    without_region: int = 0


def _hierarchy(row: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    value = row.get("hierarchy") or []
    return [entry for entry in value if isinstance(entry, Mapping)]


def rows_to_towns(rows: Iterable[Mapping[str, Any]], country: RadarCountry) -> Conversion:
    regions = app_region_names(country)
    result = Conversion()
    for row in rows:
        name = row.get("name")
        longitude, latitude = row.get("longitude"), row.get("latitude")
        if not isinstance(name, str) or not name.strip() or latitude is None or longitude is None:
            continue
        hierarchy = _hierarchy(row)
        parent = hierarchy[-2] if len(hierarchy) >= 2 else None
        seat = parent is None or parent.get("subtype") != "locality"
        region = regions.get(str(row.get("region_code") or ""))
        if region is None:
            result.without_region += 1
        province = None
        if country.code == DEFAULT_COUNTRY:
            county = next(
                (str(e.get("name")) for e in hierarchy if e.get("subtype") == "county"), None
            )
            province = province_code(county)
            if province is None and county is None and region == "Valle d'Aosta":
                # The region has no provinces; its abbreviation is AO.
                province = "AO"
            if province is None:
                result.unknown_counties[county or "(nessuna provincia)"] += 1
        result.licenses[str(row.get("license") or "non indicata")] += 1
        result.towns.append(
            Town(
                name=name.strip(),
                latitude=float(latitude),
                longitude=float(longitude),
                province=province,
                region=region,
                seat=seat,
            )
        )
    return result
