"""A latitude/longitude box that contains a whole search circle.

Used to ask the database only for the ads that can possibly be inside the radius; the
exact distance (haversine, `packages/core/domain/geo/models.py`) is still computed on
what comes back, so the box only has to be a safe superset, never exact."""

import math
from dataclasses import dataclass

from packages.core.domain.geo.models import EARTH_RADIUS_KM, Coordinates

# The box is a little larger than the circle: float rounding and the database's own
# decimal handling must never drop an ad that sits exactly on the edge of the radius.
_SAFETY = 1.001
_ALL_LONGITUDES = ((-180.0, 180.0),)


@dataclass(frozen=True)
class GeoBox:
    min_latitude: float
    max_latitude: float
    # One range, or two when the circle crosses the antimeridian (180°): each range is
    # (low, high) with -180 <= low <= high <= 180. A pole inside the circle: all of them.
    longitude_ranges: tuple[tuple[float, float], ...]

    def contains(self, point: Coordinates) -> bool:
        return self.min_latitude <= point.latitude <= self.max_latitude and any(
            low <= point.longitude <= high for low, high in self.longitude_ranges
        )


def bounding_box(center: Coordinates, radius_km: float) -> GeoBox:
    angle = min(math.pi, radius_km * _SAFETY / EARTH_RADIUS_KM)  # angular radius, radians
    min_latitude = center.latitude - math.degrees(angle)
    max_latitude = center.latitude + math.degrees(angle)
    if min_latitude <= -90.0 or max_latitude >= 90.0:
        # A pole is inside the circle (or the circle is the whole globe): every
        # longitude is possible, only the latitude can be limited.
        return GeoBox(max(-90.0, min_latitude), min(90.0, max_latitude), _ALL_LONGITUDES)

    # Largest longitude offset of the circle (at its tangent points), on a sphere.
    ratio = math.sin(angle) / math.cos(math.radians(center.latitude))
    if ratio >= 1.0:
        return GeoBox(min_latitude, max_latitude, _ALL_LONGITUDES)
    delta = math.degrees(math.asin(ratio))
    low, high = center.longitude - delta, center.longitude + delta
    ranges: tuple[tuple[float, float], ...]
    if low < -180.0:
        ranges = ((low + 360.0, 180.0), (-180.0, high))
    elif high > 180.0:
        ranges = ((low, 180.0), (-180.0, high - 360.0))
    else:
        ranges = ((low, high),)
    return GeoBox(min_latitude, max_latitude, ranges)
