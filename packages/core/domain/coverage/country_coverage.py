"""How well the radar covers a country, in the four words the app needs.

- complete: the whole country's OpenStreetMap import is in our database,
  so the radar answers from it (plus Overture where imported).
- partial: something is imported (Overture, or some OpenStreetMap regions)
  but not the full OpenStreetMap catalog.
- live: a supported country with nothing imported yet. The name comes from
  when such a country was asked of OpenStreetMap while the owner waited; today
  (RADAR_LIVE_SEARCH_ENABLED off) only the per-cell cache answers, often empty.
- unsupported: not one of the radar's countries: nothing has been prepared.
"""

from typing import Literal

from packages.core.domain.geo.countries import RadarCountry
from packages.core.domain.radar_places.models import RadarCountryCoverage

CoverageLevel = Literal["complete", "partial", "live", "unsupported"]


def coverage_level(
    country: RadarCountry | None,
    row: RadarCountryCoverage | None,
    *,
    legacy_osm_covers: bool = False,
) -> CoverageLevel:
    """`legacy_osm_covers`: the point lies inside the area recorded in
    `data_sources` by the Italy-only importer that predates the country
    table; it still counts as a complete import."""
    if country is None:
        return "unsupported"
    if legacy_osm_covers or (row is not None and row.osm_complete):
        return "complete"
    if row is not None and (row.overture_imported_at is not None or row.osm_regions):
        return "partial"
    return "live"
