"""The confirmation a seller gives for sensitive words (domain/marketplace/
content_review.py) and the team's check of those ads, after they are published."""

import logging
from datetime import UTC, datetime

from pydantic import BaseModel

from packages.core.application.ports.listing_photo_vault import ListingPhotoVault
from packages.core.application.ports.listing_review_repository import ListingReviewRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.services.removed_listings import withheld_paths
from packages.core.domain.localization import translate
from packages.core.domain.marketplace.content_review import (
    CONTENT_CONFIRMATION_REQUIRED,
    ContentNotice,
    DecisionOutcome,
    ListingDecision,
    ListingReview,
    RemovalReason,
    SensitiveTerm,
    highlighted,
    latest_by_listing,
    notices_for,
    sensitive_terms,
)
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.shared.errors.base import RequirementMissingError, VetAppError

logger = logging.getLogger(__name__)

MY_LISTINGS_LIMIT = 200
QUEUE_LIMIT = 100


class ListingReviewNotFoundError(VetAppError):
    """No such check, or its ad is gone."""


class ListingReviewConflictError(VetAppError):
    """The ad changed, or was decided, after the admin opened it."""


def confirmed_terms(
    title: str,
    description: str | None,
    category: str,
    *,
    confirmations: list[ContentNotice],
    locale: str | None,
    covered: bool = False,
) -> list[SensitiveTerm]:
    """The words the seller has just confirmed about; empty when there is nothing new to
    confirm. Refuses (400) when a box is not ticked, saying which. [covered]: this exact
    text, with these photos, was already confirmed."""
    terms = sensitive_terms(title, description, category=category)
    if not terms or covered:
        return []
    notices = notices_for(terms)
    if not set(notices) <= set(confirmations):
        message = translate("marketplace_content_confirmation_required", locale)
        raise RequirementMissingError(
            CONTENT_CONFIRMATION_REQUIRED,
            message=message,
            # The installed apps show `detail` as it comes: a sentence, not a code.
            detail=message,
            fix={
                "field": "content_confirmations",
                "value": notices,
                "terms": [{"notice": term.notice, "text": term.text} for term in terms],
            },
        )
    return terms


def new_review(listing: MarketplaceListing, terms: list[SensitiveTerm]) -> ListingReview:
    return ListingReview(
        listing_id=listing.id,
        owner_id=listing.owner_id,
        title=listing.title,
        description=listing.description,
        category=listing.category,
        photo_urls=listing.photo_urls,
        terms=[term.text for term in terms],
        notices=notices_for(terms),
    )


class OwnListing(BaseModel):
    listing: MarketplaceListing
    review: ListingReview | None


class ListingReviewService:
    def __init__(
        self,
        listings: MarketplaceListingRepository,
        reviews: ListingReviewRepository,
        vault: ListingPhotoVault,
    ) -> None:
        self._listings = listings
        self._reviews = reviews
        self._vault = vault

    def own_listings(self, owner_id: str) -> list[OwnListing]:
        """Every ad of the caller, whatever its state, newest first: the only place a
        seller finds an ad the team took down, with the reason."""
        latest = latest_by_listing(self._reviews.list_by_owner(owner_id))
        return [
            OwnListing(listing=item, review=latest.get(item.id))
            for item in self._listings.list_by_owner(owner_id, MY_LISTINGS_LIMIT)
        ]

    # -- the team (admin check: apps/api/routes/admin_common.py) ----------------

    def queue(self, limit: int = QUEUE_LIMIT) -> list[dict[str, object]]:
        """To be checked first, then what was decided: "nobody acted, the ad stays" must
        be a choice someone can see."""
        reviews = self._reviews.list_for_team(limit)
        listings = {
            item.id: item
            for item in self._listings.list_by_ids([review.listing_id for review in reviews])
        }
        return [
            self._row(review, listings[review.listing_id])
            for review in reviews
            if review.listing_id in listings
        ]

    def detail(self, review_id: str) -> dict[str, object] | None:
        review = self._reviews.get(review_id)
        listing = self._listings.get(review.listing_id) if review is not None else None
        if review is None or listing is None:
            return None
        return {
            **self._row(review, listing),
            "description": listing.description,
            "photo_urls": self._photos_for_the_team(listing),
            "price_cents": listing.price_cents,
            "city_label": listing.city_label,
            "confirmation_version": review.confirmation_version,
            "highlighted_title": highlighted(listing.title),
            "highlighted_description": highlighted(listing.description),
            "note": review.note,
        }

    def decide(
        self,
        review_id: str,
        outcome: DecisionOutcome,
        *,
        admin_id: str,
        reason: RemovalReason | None = None,
        note: str | None = None,
    ) -> MarketplaceListing:
        """Nothing is decided on a text the admin has not seen: an edit opens another
        check and closes this one. "restored" is the answer to a review asked by the
        seller."""
        review = self._reviews.get(review_id)
        listing = self._listings.get(review.listing_id) if review is not None else None
        if review is None or listing is None:
            raise ListingReviewNotFoundError
        if not self._allowed(outcome, review, listing):
            raise ListingReviewConflictError

        now = datetime.now(UTC)
        # The register and the decision are written first: an ad never changes state
        # without them.
        self._reviews.log_decision(
            ListingDecision(
                listing_id=listing.id,
                outcome=outcome,
                reason=(reason or "other") if outcome == "removed" else None,
                admin_id=admin_id,
                decided_at=now,
            )
        )
        self._reviews.save(
            review.model_copy(
                update={
                    "status": "removed" if outcome == "removed" else "checked",
                    "decided_at": now,
                    "decided_by_admin_id": admin_id,
                    "removal_reason": (reason or "other") if outcome == "removed" else None,
                    "note": note.strip() if note and note.strip() else None,
                }
            )
        )
        if outcome == "checked":
            return listing
        saved = self._listings.save(
            listing.model_copy(
                update={
                    "status": "removed_policy" if outcome == "removed" else "active",
                    "updated_at": now,
                }
            )
        )

        self._move_photos(saved)
        return saved

    def _move_photos(self, listing: MarketplaceListing) -> None:
        """The decision stands whatever the storage does: the hourly job tries again."""
        try:
            if listing.status == "removed_policy":
                self._vault.withhold(withheld_paths(listing, self._listings, self._vault))
            else:
                self._vault.release(self._vault.paths(listing.owner_id, listing.photo_urls))
        except Exception as exc:
            logger.warning("listing photos not moved yet: %s", type(exc).__name__)

    def _photos_for_the_team(self, listing: MarketplaceListing) -> list[str]:
        if listing.status != "removed_policy":
            return listing.photo_urls
        return self._vault.signed_urls(self._vault.paths(listing.owner_id, listing.photo_urls))

    @staticmethod
    def _allowed(
        outcome: DecisionOutcome, review: ListingReview, listing: MarketplaceListing
    ) -> bool:
        if not review.covers(
            listing.title, listing.description, listing.category, listing.photo_urls
        ):
            return False
        if outcome == "restored":
            return review.status == "removed" and listing.status == "removed_policy"
        if outcome == "checked":
            return review.status == "open"
        # Whatever was decided before: a removal that failed half-way can be repeated.
        return review.status != "superseded" and listing.status in ("active", "reserved")

    @staticmethod
    def _row(review: ListingReview, listing: MarketplaceListing) -> dict[str, object]:
        return {
            "id": review.id,
            "listing_id": listing.id,
            "owner_id": listing.owner_id,
            "title": listing.title,
            "category": listing.category,
            "listing_status": listing.status,
            "status": review.status,
            "terms": review.terms,
            "notices": review.notices,
            "confirmed_at": review.confirmed_at.isoformat(),
            "decided_at": review.decided_at.isoformat() if review.decided_at else None,
            "decided_by_admin_id": review.decided_by_admin_id,
            "removal_reason": review.removal_reason,
        }
