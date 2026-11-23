"""Ads the team took down: their photos leave the public bucket and everything is deleted
6 months after the decision; the register of decisions after 24 months (owner decisions
of 2026-11-23). Meant for the hourly job (POST /admin/lifecycle/prune-removed-listings).
Idempotent, counts only."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.listing_photo_vault import ListingPhotoVault
from packages.core.application.ports.listing_review_repository import (
    ListingReviewRepository,
    ListingReviewsUnavailable,
)
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.marketplace.models import MarketplaceListing

REMOVED_LISTING_RETENTION = timedelta(days=183)
DECISION_LOG_RETENTION = timedelta(days=730)
_OWNER_LISTINGS = 1000


def withheld_paths(
    listing: MarketplaceListing,
    listings: MarketplaceListingRepository,
    vault: ListingPhotoVault,
) -> list[str]:
    """The photos of a removed ad, without those another ad of the same seller still
    shows: that ad has its own check."""
    shown: set[str] = set()
    for other in listings.list_by_owner(listing.owner_id, _OWNER_LISTINGS):
        if other.id != listing.id and other.status in ("active", "reserved"):
            shown.update(vault.paths(other.owner_id, other.photo_urls))
    return [p for p in vault.paths(listing.owner_id, listing.photo_urls) if p not in shown]


class PruneRemovedListingsOutput(BaseModel):
    ran_at: datetime
    listings_deleted: int = 0
    photos_deleted: int = 0
    decisions_deleted: int = 0
    # False until the SQL script has run: the hourly job must not go red before.
    table_available: bool = True


class PruneRemovedListingsService:
    def __init__(
        self,
        listings: MarketplaceListingRepository,
        reviews: ListingReviewRepository,
        vault: ListingPhotoVault,
    ) -> None:
        self._listings = listings
        self._reviews = reviews
        self._vault = vault

    def run(self, now: datetime | None = None) -> PruneRemovedListingsOutput:
        moment = now or datetime.now(UTC)
        output = PruneRemovedListingsOutput(ran_at=moment)
        try:
            output.decisions_deleted = self._reviews.prune_decisions(
                moment - DECISION_LOG_RETENTION
            )
        except ListingReviewsUnavailable:
            output.table_available = False
            return output

        # Before the ads: a photo withheld while this runs is not in the list, so it is
        # never mistaken for a leftover.
        held = set(self._vault.held_paths())
        removed = self._removed_listings()
        for listing, decided_at in removed:
            paths = withheld_paths(listing, self._listings, self._vault)
            if decided_at < moment - REMOVED_LISTING_RETENTION:
                # Files first: with the row gone nobody would know they are there.
                output.photos_deleted += self._vault.purge(paths)
                held.difference_update(paths)
                self._listings.delete(listing.id)
                output.listings_deleted += 1
            else:
                self._vault.withhold(paths)
        output.photos_deleted += self._leftovers(held)
        return output

    def _removed_listings(self) -> list[tuple[MarketplaceListing, datetime]]:
        """The ads that are still down, each with the last decision about it."""
        decided: dict[str, datetime] = {}
        for review in self._reviews.list_removed():
            if review.decided_at is not None:
                current = decided.get(review.listing_id)
                decided[review.listing_id] = max(current or review.decided_at, review.decided_at)
        return [
            (listing, decided[listing.id])
            for listing in self._listings.list_by_ids(list(decided))
            if listing.status == "removed_policy"
        ]

    def _leftovers(self, held: set[str]) -> int:
        """Photos held for an ad that is back (a release that failed) return; those of an
        ad its seller has deleted go for good."""
        by_owner: dict[str, list[str]] = {}
        for path in sorted(held):
            by_owner.setdefault(path.split("/")[0], []).append(path)
        deleted = 0
        for owner_id, paths in by_owner.items():
            down: set[str] = set()
            shown: set[str] = set()
            for listing in self._listings.list_by_owner(owner_id, _OWNER_LISTINGS):
                target = down if listing.status == "removed_policy" else shown
                target.update(self._vault.paths(owner_id, listing.photo_urls))
            self._vault.release([path for path in paths if path in shown])
            deleted += self._vault.purge(
                [path for path in paths if path not in shown and path not in down]
            )
        return deleted
