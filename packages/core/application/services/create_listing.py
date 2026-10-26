from pydantic import BaseModel

from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.geo.models import Coordinates, approximate_coordinates
from packages.core.domain.marketplace.animal_policy import (
    ANIMAL_POLICY_MESSAGE,
    offers_animals,
)
from packages.core.domain.marketplace.models import (
    ListingCategory,
    ListingCondition,
    ListingSpecies,
    MarketplaceListing,
)
from packages.core.domain.territory.rules import is_known_country, normalize_country
from packages.shared.errors.base import ValidationError


class CreateListingInput(BaseModel):
    owner_id: str
    title: str
    category: ListingCategory
    condition: ListingCondition
    exact_location: Coordinates
    description: str | None = None
    price_cents: int | None = None
    photo_urls: list[str] = []
    target_species: list[ListingSpecies] = []
    city_label: str | None = None
    country: str = "IT"


class CreateListingOutput(BaseModel):
    listing: MarketplaceListing


class CreateListingService:
    """The only place a seller's exact coordinates are allowed to exist -
    `exact_location` never reaches the repository, only the grid-snapped result
    does (see geo.models.approximate_coordinates)."""

    def __init__(self, repository: MarketplaceListingRepository) -> None:
        self._repository = repository

    def execute(self, data: CreateListingInput) -> CreateListingOutput:
        if not is_known_country(data.country):
            raise ValidationError("Paese non supportato per il Mercatino.")
        country = normalize_country(data.country)
        # The Mercatino sells things for animals, never animals, in every
        # country: this is the check that decides, whatever the app did.
        if offers_animals(data.title, data.description):
            raise ValidationError(ANIMAL_POLICY_MESSAGE)
        listing = MarketplaceListing(
            owner_id=data.owner_id,
            title=data.title,
            description=data.description,
            category=data.category,
            condition=data.condition,
            price_cents=data.price_cents,
            photo_urls=data.photo_urls,
            target_species=data.target_species,
            city_label=data.city_label,
            country=country,
            location=approximate_coordinates(data.exact_location),
        )
        return CreateListingOutput(listing=self._repository.save(listing))
