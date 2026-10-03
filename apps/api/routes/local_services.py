from typing import Annotated

from fastapi import APIRouter, Query

from apps.api.dependencies.container import get_container
from packages.core.application.services.list_nearby_radar_places import (
    ListNearbyRadarPlacesInput,
)
from packages.core.domain.radar_places.models import (
    RADAR_PLACE_TRANSIENT_FIELDS,
    RadarPlaceType,
)

router = APIRouter(prefix="/local-services", tags=["local-services"])


# Deliberately no bulk/export variant of this route: the cache holds
# OpenStreetMap data (ODbL), and serving it only as bounded, distance-
# filtered results keeps the app a "produced work" rather than a
# redistributed derivative database (docs/features/radar_places_overpass.md).
@router.get("/places")
def list_nearby_places(
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    radius_km: Annotated[float | None, Query(gt=0)] = None,
    place_type: Annotated[list[RadarPlaceType] | None, Query()] = None,
    per_type_limit: Annotated[int, Query(ge=1, le=400)] = 60,
) -> dict[str, object]:
    container = get_container()
    container.auth_provider.get_current_user()
    result = container.list_nearby_radar_places_service().execute(
        ListNearbyRadarPlacesInput(
            latitude=latitude,
            longitude=longitude,
            radius_km=radius_km,
            place_types=list(place_type or []),
            per_type_limit=per_type_limit,
        )
    )
    return {
        "places": [
            {
                **item.place.model_dump(mode="json", exclude=set(RADAR_PLACE_TRANSIENT_FIELDS)),
                "distance_km": round(item.distance_km, 3),
            }
            for item in result.places
        ],
        "coverage": {
            "coverage_key": result.coverage.coverage_key,
            "status": result.coverage_status,
            "source_name": result.coverage.source_name,
            "refreshed_at": result.coverage.refreshed_at.isoformat(),
        },
        "context": {
            "search_radius_km": result.search_radius_km,
        },
    }
