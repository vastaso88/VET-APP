from typing import Annotated

from fastapi import APIRouter, Query

from apps.api.dependencies.container import get_container
from packages.core.application.services.list_nearby_listings import ListNearbyListingsInput
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.models import ListingCategory
from packages.core.domain.territory.rules import MARKETPLACE_MAX_RADIUS_KM

router = APIRouter(prefix="/marketplace", tags=["marketplace"])


# The Mercatino is local: no radius, no search. `radius_km` has no default and
# a value outside (0, MARKETPLACE_MAX_RADIUS_KM] is refused (400), whatever
# the app sends; `country` picks the only ads that are ever returned.
@router.get("/listings")
def list_nearby_listings(
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
    radius_km: Annotated[float, Query()],
    country: Annotated[str, Query(min_length=2, max_length=2)],
    category: ListingCategory | None = None,
) -> dict[str, object]:
    container = get_container()
    container.auth_provider.get_current_user()
    result = container.list_nearby_listings_service().execute(
        ListNearbyListingsInput(
            buyer_location=Coordinates(latitude=latitude, longitude=longitude),
            max_distance_km=radius_km,
            country=country,
            category=category,
        )
    )
    listings = []
    for item in result.listings:
        row = item.model_dump(mode="json", exclude={"location"})
        row["latitude"] = item.location.latitude
        row["longitude"] = item.location.longitude
        row["distance_km"] = round(result.distances_km[item.id], 3)
        listings.append(row)
    return {
        "listings": listings,
        "context": {
            "country": country.upper(),
            "radius_km": radius_km,
            "max_radius_km": MARKETPLACE_MAX_RADIUS_KM,
        },
    }
