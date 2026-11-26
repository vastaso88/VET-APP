"""Back-of-the-envelope size and time of importing each country, worked
out BEFORE any import runs (docs/maps/COUNTRIES.md has the table).

Italy is the only country actually measured (2026-10-04 / 2026-10-07):
8,069 OpenStreetMap places and 15,831 Overture places after filtering,
about 9 MB in the database for each source, 20 OSM regions in 10-15
minutes, Overture in 3 minutes 11 seconds. The other countries scale that
by population, area and how well each source covers the country; every
figure is an estimate, good to about +/-50%, and the first `--dry-run` of
each country replaces it with a measurement.

Overture was measured on 2026-11-26 (release 2026-11-18.0, dry runs, with the
categories added that day) for
Germany, France, Spain, the United Kingdom and Australia: places after the
filters and minutes of download (`overture_measured`). Their MB are still
places x the Italian row size. OSM is not measured for them: OSM imports
are paused (docs/maps/COUNTRIES.md §2).
"""

from dataclasses import dataclass

from packages.core.domain.geo.countries import RADAR_COUNTRIES, RadarCountry

# Measured on Italy: 9 MB / 15,831 rows and 9 MB / 8,069 rows (table plus
# position index). OSM rows are heavier: species, details, hours.
OVERTURE_ROW_BYTES = 590
OSM_ROW_BYTES = 1100

# Supabase free plan database size.
FREE_PLAN_DATABASE_MB = 500

# One Overpass region: ~36 s on average in the Italian run (download plus
# the 5 s pause); a refused region is fetched one category at a time, up to
# this many extra queries.
SECONDS_PER_OSM_REGION = 36
MAX_QUERIES_PER_REFUSED_REGION = 10


@dataclass(frozen=True)
class CountryEstimate:
    country: str
    overture_places: int
    osm_places: int
    overture_minutes: tuple[int, int]
    osm_minutes: tuple[int, int]
    measured: bool = False
    # Overture places and minutes come from a dry run, OSM is still estimated.
    overture_measured: bool = False

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
    "IT": CountryEstimate("IT", 15_831, 8_069, (3, 4), (10, 15), measured=True),
    "DE": CountryEstimate("DE", 21_335, 38_000, (8, 8), (12, 20), overture_measured=True),
    "FR": CountryEstimate("FR", 14_755, 22_000, (10, 10), (10, 18), overture_measured=True),
    "ES": CountryEstimate("ES", 12_045, 12_000, (18, 18), (12, 20), overture_measured=True),
    "GB": CountryEstimate("GB", 37_586, 22_000, (7, 7), (10, 30), overture_measured=True),
    # AU OSM: Geofabrik extract read with pyosmium (osm_pbf.py), 2026-11-26.
    "AU": CountryEstimate(
        "AU", 9_697, 3_397, (1, 1), (4, 4), measured=True, overture_measured=True
    ),
    "US": CountryEstimate("US", 130_000, 90_000, (20, 45), (45, 150)),
}


def overpass_requests(country: RadarCountry) -> tuple[int, int]:
    """Overpass queries: one per region at best, one per category in every
    region at worst (plus a status check before each, not counted)."""
    regions = len(country.regions)
    return regions, regions * (1 + MAX_QUERIES_PER_REFUSED_REGION)


def estimate_for(country: RadarCountry) -> CountryEstimate:
    return COUNTRY_ESTIMATES[country.code]


def total_database_mb(codes: list[str] | None = None) -> float:
    wanted = codes or [country.code for country in RADAR_COUNTRIES]
    return sum(COUNTRY_ESTIMATES[code].total_mb for code in wanted)
