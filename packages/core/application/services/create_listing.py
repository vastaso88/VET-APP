from datetime import datetime

from pydantic import BaseModel

from packages.core.application.ports.listing_photo_vault import ListingPhotoVault
from packages.core.application.ports.listing_review_repository import ListingReviewRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.services.listing_photos import (
    clean_up,
    plan_photos,
    published,
)
from packages.core.application.services.listing_review import confirmed_terms, new_review
from packages.core.domain.geo.models import Coordinates, approximate_coordinates
from packages.core.domain.marketplace.animal_policy import (
    ANIMAL_POLICY_MESSAGE,
    offers_animals,
)
from packages.core.domain.marketplace.content_policy import (
    CONTACT_POLICY_MESSAGE,
    MEDICINE_POLICY_MESSAGE,
    contains_contact_details,
    refused_terms,
)
from packages.core.domain.marketplace.content_review import ContentNotice
from packages.core.domain.marketplace.models import (
    ListingCategory,
    ListingCondition,
    ListingSpecies,
    MarketplaceListing,
)
from packages.core.domain.territory.rules import is_known_country, normalize_country
from packages.shared.errors.base import ContentRefusedError, ValidationError


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
    private_seller_declared_at: datetime | None = None
    private_seller_declaration_version: str | None = None
    # The boxes the seller ticked (content_review.py).
    content_confirmations: list[ContentNotice] = []
    locale: str | None = None


class CreateListingOutput(BaseModel):
    listing: MarketplaceListing


class CreateListingService:
    """The only place a seller's exact coordinates are allowed to exist -
    `exact_location` never reaches the repository, only the grid-snapped result
    does (see geo.models.approximate_coordinates)."""

    def __init__(
        self,
        repository: MarketplaceListingRepository,
        reviews: ListingReviewRepository | None = None,
        vault: ListingPhotoVault | None = None,
    ) -> None:
        self._repository = repository
        self._reviews = reviews
        self._vault = vault

    def execute(self, data: CreateListingInput) -> CreateListingOutput:
        if not is_known_country(data.country):
            raise ValidationError("Paese non supportato per il Mercatino.")
        country = normalize_country(data.country)
        # The Mercatino sells things for animals, never animals, in every
        # country: this is the check that decides, whatever the app did.
        if offers_animals(data.title, data.description):
            raise ValidationError(ANIMAL_POLICY_MESSAGE)
        # The text is public to every owner nearby: no phone numbers, e-mails,
        # web sites or handles in it; and no veterinary medicines (retail only
        # by authorised sellers, Reg. (EU) 2019/6).
        if contains_contact_details(data.title, data.description):
            raise ValidationError(CONTACT_POLICY_MESSAGE)
        refused = refused_terms(data.title, data.description)
        if refused:
            # One refusal for medicines and active substances, in the words the installed
            # apps already know. Nothing of the text is kept.
            raise ContentRefusedError(MEDICINE_POLICY_MESSAGE, terms=refused)
        plan = plan_photos(data.photo_urls, data.owner_id, self._vault)
        terms = confirmed_terms(
            data.title,
            data.description,
            data.category,
            confirmations=data.content_confirmations,
            locale=data.locale,
        )
        listing = MarketplaceListing(
            owner_id=data.owner_id,
            title=data.title,
            description=data.description,
            category=data.category,
            condition=data.condition,
            price_cents=data.price_cents,
            target_species=data.target_species,
            city_label=data.city_label,
            country=country,
            location=approximate_coordinates(data.exact_location),
            # The confirmation is the only barrier before the ad is online: it is
            # visible only once that is recorded.
            status="removed" if terms else "active",
            private_seller_declared_at=data.private_seller_declared_at,
            private_seller_declaration_version=data.private_seller_declaration_version,
        )
        # Last of all, when nothing else can refuse the ad: the copies of the photos.
        with published(plan, listing.id, self._vault, self._repository) as links:
            saved = self._repository.save(listing.model_copy(update={"photo_urls": links}))
            if terms:
                try:
                    if self._reviews is not None:
                        self._reviews.save(new_review(saved, terms))
                    saved = self._repository.save(saved.model_copy(update={"status": "active"}))
                except Exception:
                    # The seller will try again: no hidden copy of the failed one.
                    self._repository.delete(saved.id)
                    raise
        clean_up(plan, self._vault, self._repository, before=None, after=saved)
        return CreateListingOutput(listing=saved)
