from datetime import datetime

from pydantic import BaseModel

from packages.core.application.ports.listing_review_repository import ListingReviewRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.services.listing_review import confirmed_terms, new_review
from packages.core.domain.common.entity import utc_now
from packages.core.domain.geo.models import Coordinates, approximate_coordinates
from packages.core.domain.marketplace.animal_policy import (
    ANIMAL_POLICY_MESSAGE,
    offers_animals,
)
from packages.core.domain.marketplace.content_policy import (
    CONTACT_POLICY_MESSAGE,
    MEDICINE_POLICY_MESSAGE,
    contains_contact_details,
    offers_active_substances,
    offers_medicines,
)
from packages.core.domain.marketplace.content_review import ContentNotice, latest_by_listing
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
    private_seller_declared_at: datetime | None = None
    private_seller_declaration_version: str | None = None
    # The boxes the seller ticked (content_review.py).
    content_confirmations: list[ContentNotice] = []
    locale: str | None = None


class UpdateListingOutput(BaseModel):
    listing: MarketplaceListing


class UpdateListingService:
    """Edits an ad of its author. Runs the same content rule as the creation
    (a title or description cannot be changed into an animal offer), and never
    touches the status, the report count or the owner. A new text or new photos of an
    ad with sensitive words need the confirmation again."""

    def __init__(
        self,
        repository: MarketplaceListingRepository,
        reviews: ListingReviewRepository | None = None,
    ) -> None:
        self._repository = repository
        self._reviews = reviews

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
        # The text is public to every owner nearby: no phone numbers, e-mails,
        # web sites or handles in it; and no veterinary medicines (retail only
        # by authorised sellers, Reg. (EU) 2019/6).
        if contains_contact_details(data.title, data.description):
            raise ValidationError(CONTACT_POLICY_MESSAGE)
        if offers_medicines(data.title, data.description) or offers_active_substances(
            data.title, data.description
        ):
            # One refusal for both, in the words the installed apps already know.
            raise ValidationError(MEDICINE_POLICY_MESSAGE)

        latest = None
        if self._reviews is not None:
            latest = latest_by_listing(self._reviews.list_by_listings([current.id])).get(current.id)
        # The same text and photos, already confirmed: a new price needs nothing.
        covered = (
            latest is not None
            and latest.status in ("open", "checked")
            and latest.covers(data.title, data.description, data.category, data.photo_urls)
        )
        terms = confirmed_terms(
            data.title,
            data.description,
            data.category,
            confirmations=data.content_confirmations,
            locale=data.locale,
            covered=covered,
        )

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
                "private_seller_declared_at": (
                    data.private_seller_declared_at or current.private_seller_declared_at
                ),
                "private_seller_declaration_version": (
                    data.private_seller_declaration_version
                    or current.private_seller_declaration_version
                ),
            }
        )
        # The records first: an ad is never online with words nobody confirmed.
        if self._reviews is not None and not covered:
            if terms:
                self._reviews.save(new_review(updated, terms))
            if latest is not None and latest.status == "open":
                self._reviews.save(latest.model_copy(update={"status": "superseded"}))
        return UpdateListingOutput(listing=self._repository.save(updated))
