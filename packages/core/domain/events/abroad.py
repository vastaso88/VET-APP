"""Which events of another country an owner sees (owner's decision of 2026-11-25, card F42).

International events: always. Every other event of another country, whatever its reach
(national, regional, local): only when it takes place just over the border, within
[ABROAD_RADIUS_KM] of the owner's saved Località. Without a Località, or without the
coordinates of the event, it is not shown.
"""

from packages.core.domain.geo.models import Coordinates, haversine_distance_km

ABROAD_RADIUS_KM = 30.0
INTERNATIONAL_LEVEL = "international"


def is_near_border(*, place: Coordinates | None, owner: Coordinates | None) -> bool:
    return (
        place is not None
        and owner is not None
        and haversine_distance_km(owner, place) <= ABROAD_RADIUS_KM
    )


def is_shown_abroad(*, level: object, place: Coordinates | None, owner: Coordinates | None) -> bool:
    return level == INTERNATIONAL_LEVEL or is_near_border(place=place, owner=owner)
