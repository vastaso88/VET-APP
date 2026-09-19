from pydantic import BaseModel

from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.marketplace.models import ListingCategory, MarketplaceListing


class ListNearbyListingsInput(BaseModel):
    buyer_location: Coordinates
    max_distance_km: float
    category: ListingCategory | None = None


class ListNearbyListingsOutput(BaseModel):
    listings: list[MarketplaceListing]


class ListNearbyListingsService:
    """Filters/sorts in Python, not SQL - fine at MVP scale, and it keeps
    the fuzzed-coordinate privacy boundary entirely inside this codebase
    rather than depending on a geo-aware database extension."""

    def __init__(self, repository: MarketplaceListingRepository) -> None:
        self._repository = repository

    def execute(self, data: ListNearbyListingsInput) -> ListNearbyListingsOutput:
        candidates = self._repository.list_active()
        if data.category is not None:
            candidates = [item for item in candidates if item.category == data.category]

        nearby = [
            item
            for item in candidates
            if haversine_distance_km(data.buyer_location, item.location) <= data.max_distance_km
        ]
        nearby.sort(key=lambda item: haversine_distance_km(data.buyer_location, item.location))
        return ListNearbyListingsOutput(listings=nearby)
