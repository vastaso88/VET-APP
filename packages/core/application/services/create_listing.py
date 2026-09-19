from pydantic import BaseModel

from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.geo.models import Coordinates, fuzz_coordinates
from packages.core.domain.marketplace.models import (
    ListingCategory,
    ListingCondition,
    MarketplaceListing,
)


class CreateListingInput(BaseModel):
    owner_id: str
    title: str
    category: ListingCategory
    condition: ListingCondition
    exact_location: Coordinates
    description: str | None = None
    price_cents: int | None = None
    photo_urls: list[str] = []
    city_label: str | None = None


class CreateListingOutput(BaseModel):
    listing: MarketplaceListing


class CreateListingService:
    """The only place a seller's exact coordinates are allowed to exist -
    `exact_location` never reaches the repository, only the fuzzed result
    does (see geo.models.fuzz_coordinates)."""

    def __init__(self, repository: MarketplaceListingRepository) -> None:
        self._repository = repository

    def execute(self, data: CreateListingInput) -> CreateListingOutput:
        listing = MarketplaceListing(
            owner_id=data.owner_id,
            title=data.title,
            description=data.description,
            category=data.category,
            condition=data.condition,
            price_cents=data.price_cents,
            photo_urls=data.photo_urls,
            city_label=data.city_label,
            # location is set after id assignment below, since fuzzing is
            # seeded from the listing id.
            location=data.exact_location,
        )
        listing = listing.model_copy(
            update={"location": fuzz_coordinates(data.exact_location, listing.id)}
        )
        return CreateListingOutput(listing=self._repository.save(listing))
