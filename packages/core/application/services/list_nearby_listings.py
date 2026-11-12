from pydantic import BaseModel

from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.marketplace.models import ListingCategory, MarketplaceListing
from packages.core.domain.territory.rules import (
    MARKETPLACE_MAX_RADIUS_KM,
    MARKETPLACE_MIN_RADIUS_KM,
)
from packages.shared.errors.base import ValidationError


class ListNearbyListingsInput(BaseModel):
    buyer_location: Coordinates
    # Required, never defaulted: the Mercatino is local, a search always has a
    # radius. Validated in the service (MIN_RADIUS_KM <= radius <= MAX_RADIUS_KM).
    max_distance_km: float
    category: ListingCategory | None = None


class ListNearbyListingsOutput(BaseModel):
    listings: list[MarketplaceListing]
    distances_km: dict[str, float] = {}


class ListNearbyListingsService:
    """Filters/sorts in Python, not SQL - fine at MVP scale, and it keeps
    the fuzzed-coordinate privacy boundary entirely inside this codebase
    rather than depending on a geo-aware database extension.

    Hard rules (owner decisions 2026-10-14 and 2026-10-26): the radius is
    mandatory, between ``MARKETPLACE_MIN_RADIUS_KM`` and
    ``MARKETPLACE_MAX_RADIUS_KM``, and it is the only filter on where an ad is
    (across a border too); only ``active`` ads are ever returned."""

    def __init__(self, repository: MarketplaceListingRepository) -> None:
        self._repository = repository

    def execute(self, data: ListNearbyListingsInput) -> ListNearbyListingsOutput:
        radius = data.max_distance_km
        if not MARKETPLACE_MIN_RADIUS_KM <= radius <= MARKETPLACE_MAX_RADIUS_KM:
            raise ValidationError(
                "Il raggio di ricerca deve essere tra "
                f"{MARKETPLACE_MIN_RADIUS_KM:g} e {MARKETPLACE_MAX_RADIUS_KM:g} km."
            )

        # Distance is the filter: a buyer near a border also sees the ads just
        # across it (each one carries its seller's country, flag and currency).
        candidates = self._repository.list_active()
        if data.category is not None:
            candidates = [item for item in candidates if item.category == data.category]

        distances = {
            item.id: haversine_distance_km(data.buyer_location, item.location)
            for item in candidates
        }
        nearby = [item for item in candidates if distances[item.id] <= radius]
        nearby.sort(key=lambda item: distances[item.id])
        return ListNearbyListingsOutput(
            listings=nearby, distances_km={item.id: distances[item.id] for item in nearby}
        )
