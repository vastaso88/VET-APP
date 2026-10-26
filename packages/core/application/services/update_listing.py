from pydantic import BaseModel

from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.common.entity import utc_now
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


class UpdateListingInput(BaseModel):
    owner_id: str
    listing_id: str
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


class UpdateListingOutput(BaseModel):
    listing: MarketplaceListing


class UpdateListingService:
    """Edits an ad of its author. Runs the same content rule as the creation
    (a title or description cannot be changed into an animal offer), and never
    touches the status, the report count or the owner."""

    def __init__(self, repository: MarketplaceListingRepository) -> None:
        self._repository = repository

    def execute(self, data: UpdateListingInput) -> UpdateListingOutput:
        current = self._repository.get(data.listing_id)
        # Someone else's ad looks exactly like a missing one.
        if current is None or current.owner_id != data.owner_id:
            raise ValidationError("Annuncio non trovato.")
        if current.status not in ("active", "reserved"):
            raise ValidationError("Questo annuncio non si può più modificare.")
        if not is_known_country(data.country):
            raise ValidationError("Paese non supportato per il Mercatino.")
        if offers_animals(data.title, data.description):
            raise ValidationError(ANIMAL_POLICY_MESSAGE)

        updated = current.model_copy(
            update={
                "title": data.title,
                "description": data.description,
                "category": data.category,
                "condition": data.condition,
                "price_cents": data.price_cents,
                "photo_urls": data.photo_urls,
                "target_species": data.target_species,
                "city_label": data.city_label,
                "country": normalize_country(data.country),
                "location": approximate_coordinates(data.exact_location),
                "updated_at": utc_now(),
            }
        )
        return UpdateListingOutput(listing=self._repository.save(updated))
