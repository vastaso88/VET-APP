"""The confirmation a seller gives for sensitive words (domain/marketplace/
content_review.py) and the team's check of those ads, after they are published."""

from datetime import UTC, datetime
from typing import Literal

from pydantic import BaseModel

from packages.core.application.ports.listing_photo_vault import ListingPhotoVault
from packages.core.application.ports.listing_report_repository import ListingReportRepository
from packages.core.application.ports.listing_review_repository import ListingReviewRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.services.removed_listings import HIDDEN, move_photos
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
from packages.core.domain.marketplace.models import (
    REPORT_COUNT_AUTO_REMOVE_THRESHOLD,
    ListingReport,
    ListingStatus,
    MarketplaceListing,
)
from packages.shared.errors.base import RequirementMissingError, VetAppError

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


class HiddenNotice(BaseModel):
    """Why the seller's own ad is not visible: never who reported it or who decided."""

    # team: a person decided. reports: hidden on its own after enough reports, until the
    # team looks. rule: the automatic rule on animals.
    kind: Literal["team", "reports", "rule"]
    reason: RemovalReason | None = None
    since: datetime
    terms: list[str] = []


class OwnListing(BaseModel):
    listing: MarketplaceListing
    hidden: HiddenNotice | None


def _hidden_by_reports(listing: MarketplaceListing, reports: list[ListingReport]) -> HiddenNotice:
    """Since the day the last needed report came in; what people wrote stays with the team."""
    counted = [item for item in reports if item.status == "open"] or reports
    first_by_reporter: dict[str, datetime] = {}
    for item in sorted(counted, key=lambda report: report.created_at):
        first_by_reporter.setdefault(item.reporter_owner_id, item.created_at)
    needed = list(first_by_reporter.values())[:REPORT_COUNT_AUTO_REMOVE_THRESHOLD]
    # Nobody left: the people who reported it have deleted their accounts.
    return HiddenNotice(kind="reports", since=needed[-1] if needed else listing.updated_at)


class ListingReviewService:
    def __init__(
        self,
        listings: MarketplaceListingRepository,
        reviews: ListingReviewRepository,
        vault: ListingPhotoVault,
        reports: ListingReportRepository,
    ) -> None:
        self._listings = listings
        self._reviews = reviews
        self._vault = vault
        self._reports = reports

    def own_listings(self, owner_id: str) -> list[OwnListing]:
        """Every ad of the caller, whatever its state, newest first: the only place a
        seller finds an ad the team took down, with the reason."""
        latest = latest_by_listing(self._reviews.list_by_owner(owner_id))
        mine = self._listings.list_by_owner(owner_id, MY_LISTINGS_LIMIT)
        reported: dict[str, list[ListingReport]] = {}
        hidden_ids = [item.id for item in mine if item.status == "removed"]
        for report in self._reports.list_by_listings(hidden_ids) if hidden_ids else []:
            reported.setdefault(report.listing_id, []).append(report)
        return [
            OwnListing(
                listing=item,
                hidden=self._why_hidden(item, latest.get(item.id), reported.get(item.id, [])),
            )
            for item in mine
        ]

    @staticmethod
    def _why_hidden(
        listing: MarketplaceListing, review: ListingReview | None, reports: list[ListingReport]
    ) -> HiddenNotice | None:
        if listing.status == "removed":
            return _hidden_by_reports(listing, reports)
        if listing.status != "removed_policy":
            return None
        if review is None or review.status != "removed" or review.decided_at is None:
            return HiddenNotice(kind="rule", reason="sells_animals", since=listing.updated_at)
        return HiddenNotice(
            kind="team",
            reason=review.removal_reason or "other",
            since=review.decided_at,
            terms=review.terms,
        )

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
            # Links to other sites are counted, never handed on.
            "photos_not_shown": len(listing.photo_urls) - len(self._vault.paths(listing)),
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
        self._log(
            listing.id,
            outcome,
            admin_id,
            now,
            (reason or "other") if outcome == "removed" else None,
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
        status: ListingStatus = "removed_policy" if outcome == "removed" else "active"
        return self._set_status(listing, status, now)

    def _photos_for_the_team(self, listing: MarketplaceListing) -> list[str]:
        paths = self._vault.paths(listing)
        return (
            self._vault.signed_urls(paths)
            if listing.status in HIDDEN
            else self._vault.public_urls(paths)
        )

    # -- from the queue of reports (apps/api/routes/admin_moderation.py) ----------

    def remove_reported(
        self, listing_id: str, reason: RemovalReason, *, admin_id: str, note: str | None = None
    ) -> MarketplaceListing:
        """The same decision as from the queue of checks: reason and date for the seller,
        register, photos, 6 months. Already taken down: nothing changes."""
        listing = self._listings.get(listing_id)
        if listing is None:
            raise ListingReviewNotFoundError
        if listing.status == "removed_policy":
            return listing
        now = datetime.now(UTC)
        self._log(listing.id, "removed", admin_id, now, reason)
        for review in self._reviews.list_by_listings([listing.id]):
            if review.status == "open":
                self._reviews.save(review.model_copy(update={"status": "superseded"}))
        self._reviews.save(
            ListingReview(
                listing_id=listing.id,
                owner_id=listing.owner_id,
                status="removed",
                origin="report",
                title=listing.title,
                description=listing.description,
                category=listing.category,
                photo_urls=listing.photo_urls,
                confirmed_at=now,
                confirmation_version="",
                decided_at=now,
                decided_by_admin_id=admin_id,
                removal_reason=reason,
                note=note.strip() if note and note.strip() else None,
            )
        )
        return self._set_status(listing, "removed_policy", now)

    def restore_reported(self, listing_id: str, *, admin_id: str) -> MarketplaceListing:
        listing = self._listings.get(listing_id)
        if listing is None:
            raise ListingReviewNotFoundError
        if listing.status not in HIDDEN:
            return listing
        now = datetime.now(UTC)
        self._log(listing.id, "restored", admin_id, now)
        latest = latest_by_listing(self._reviews.list_by_listings([listing.id])).get(listing.id)
        if latest is not None and latest.status == "removed":
            self._reviews.save(
                latest.model_copy(
                    update={
                        "status": "checked",
                        "decided_at": now,
                        "decided_by_admin_id": admin_id,
                        "removal_reason": None,
                    }
                )
            )
        return self._set_status(listing, "active", now)

    def _log(
        self,
        listing_id: str,
        outcome: DecisionOutcome,
        admin_id: str,
        now: datetime,
        reason: RemovalReason | None = None,
    ) -> None:
        self._reviews.log_decision(
            ListingDecision(
                listing_id=listing_id,
                outcome=outcome,
                reason=reason,
                admin_id=admin_id,
                decided_at=now,
            )
        )

    def _set_status(
        self, listing: MarketplaceListing, status: ListingStatus, now: datetime
    ) -> MarketplaceListing:
        saved = self._listings.save(
            listing.model_copy(update={"status": status, "updated_at": now})
        )
        move_photos(saved, self._listings, self._vault)
        return saved

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
            "origin": review.origin,
            "terms": review.terms,
            "notices": review.notices,
            "confirmed_at": review.confirmed_at.isoformat(),
            "decided_at": review.decided_at.isoformat() if review.decided_at else None,
            "decided_by_admin_id": review.decided_by_admin_id,
            "removal_reason": review.removal_reason,
        }
