"""Size and time of importing each country (docs/maps/COUNTRIES.md has the
table, printed by scripts/radar/estimate_countries.py).

Measured on 2026-11-26 for Italy, Germany, France, Spain, the United
Kingdom and Australia (dry runs, nothing written):

- Overture: release 2026-11-18.0 with the categories added that day, places
  after the filters and minutes of download (Italy: the 2026-10 import,
  before those categories).
- OpenStreetMap: the country's Geofabrik extract read with pyosmium
  (scripts/radar/import_osm_places.py), places after the same mapping the
  Overpass answers had; minutes are download plus reading, so they depend
  on the line (Germany's download took 50 minutes, France's 7).

MB are places x the bytes per row measured on Italy's tables (a dry run
does not write). The United States are still an estimate (+/-50%).
"""

from dataclasses import dataclass

from packages.core.domain.geo.countries import RADAR_COUNTRIES, RadarCountry

# Measured on Italy: 9 MB / 15,831 rows and 9 MB / 8,069 rows (table plus
# position index). OSM rows are heavier: species, details, hours.
OVERTURE_ROW_BYTES = 590
OSM_ROW_BYTES = 1100

# Supabase free plan database size.
FREE_PLAN_DATABASE_MB = 500


@dataclass(frozen=True)
class CountryEstimate:
    country: str
    overture_places: int
    osm_places: int
    overture_minutes: tuple[int, int]
    osm_minutes: tuple[int, int]
    # Size of the Geofabrik extract downloaded for OSM, in MB (0: unknown).
    extract_mb: int = 0
    measured: bool = False

    @property
    def overture_mb(self) -> float:
        return self.overture_places * OVERTURE_ROW_BYTES / 1_000_000

    @property
    def osm_mb(self) -> float:
        return self.osm_places * OSM_ROW_BYTES / 1_000_000

    @property
    def total_mb(self) -> float:
        return self.overture_mb + self.osm_mb


# Places are the ones left after the importers' filters (confidence >= 0.7,
# not closed, duplicates merged), not raw rows.
COUNTRY_ESTIMATES: dict[str, CountryEstimate] = {
    "IT": CountryEstimate("IT", 15_831, 8_679, (3, 4), (5, 5), 2_256, measured=True),
    "DE": CountryEstimate("DE", 21_335, 13_467, (8, 8), (54, 54), 4_891, measured=True),
    "FR": CountryEstimate("FR", 14_755, 9_691, (10, 10), (12, 12), 5_122, measured=True),
    "ES": CountryEstimate("ES", 12_045, 6_915, (18, 18), (3, 3), 1_506, measured=True),
    "GB": CountryEstimate("GB", 37_586, 8_368, (7, 7), (6, 6), 2_292, measured=True),
    "AU": CountryEstimate("AU", 9_697, 3_395, (1, 1), (2, 2), 978, measured=True),
    "US": CountryEstimate("US", 130_000, 90_000, (20, 45), (45, 150)),
}


def estimate_for(country: RadarCountry) -> CountryEstimate:
    return COUNTRY_ESTIMATES[country.code]


def total_database_mb(codes: list[str] | None = None) -> float:
    wanted = codes or [country.code for country in RADAR_COUNTRIES]
    return sum(COUNTRY_ESTIMATES[code].total_mb for code in wanted)
