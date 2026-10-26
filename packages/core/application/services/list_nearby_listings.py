from pydantic import BaseModel

from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.geo.models import Coordinates, haversine_distance_km
from packages.core.domain.marketplace.models import ListingCategory, MarketplaceListing
from packages.core.domain.territory.rules import (
    MARKETPLACE_MAX_RADIUS_KM,
    is_known_country,
    normalize_country,
)
from packages.shared.errors.base import ValidationError


class ListNearbyListingsInput(BaseModel):
    buyer_location: Coordinates
    # Required, never defaulted: the Mercatino is local, a search always has a
    # radius. Validated in the service (0 < radius <= MARKETPLACE_MAX_RADIUS_KM).
    max_distance_km: float
    country: str
    category: ListingCategory | None = None


class ListNearbyListingsOutput(BaseModel):
    listings: list[MarketplaceListing]
    distances_km: dict[str, float] = {}


class ListNearbyListingsService:
    """Filters/sorts in Python, not SQL - fine at MVP scale, and it keeps
    the fuzzed-coordinate privacy boundary entirely inside this codebase
    rather than depending on a geo-aware database extension.

    Three hard rules (owner decisions 2026-10-14): the radius is mandatory and
    capped at ``MARKETPLACE_MAX_RADIUS_KM``; only ads of the asker's country
    are ever returned; nothing is served for an unknown country."""

    def __init__(self, repository: MarketplaceListingRepository) -> None:
        self._repository = repository

    def execute(self, data: ListNearbyListingsInput) -> ListNearbyListingsOutput:
        radius = data.max_distance_km
        if not 0 < radius <= MARKETPLACE_MAX_RADIUS_KM:
            raise ValidationError(
                f"Il raggio di ricerca deve essere tra 0 e {MARKETPLACE_MAX_RADIUS_KM:g} km."
            )
        if not is_known_country(data.country):
            raise ValidationError("Paese non supportato per il Mercatino.")
        country = normalize_country(data.country)

        candidates = [
            item for item in self._repository.list_active(country) if item.country == country
        ]
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
