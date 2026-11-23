"""Hidden ads: their photos leave the public bucket. An ad the team took down is deleted
6 months after the decision; the register of decisions after 24 months (owner decisions
of 2026-11-23). Meant for the hourly job (POST /admin/lifecycle/prune-removed-listings).
Idempotent, counts only."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from pydantic import BaseModel

from packages.core.application.ports.listing_photo_vault import ListingPhotoVault, StoredPhoto
from packages.core.application.ports.listing_review_repository import (
    ListingReviewRepository,
    ListingReviewsUnavailable,
)
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.services.listing_photos import used_elsewhere
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.core.domain.marketplace.photos import PUBLISHED, mentioned_paths

logger = logging.getLogger(__name__)

REMOVED_LISTING_RETENTION = timedelta(days=183)
DECISION_LOG_RETENTION = timedelta(days=730)
_OWNER_LISTINGS = 1000
_HIDDEN_PER_RUN = 1000
# States nobody but the seller sees.
HIDDEN = ("removed", "removed_policy")
# A new ad is hidden for an instant while its confirmation is recorded.
_SETTLED = timedelta(minutes=10)
# Beyond these the leftovers are not deleted without someone looking.
LEFTOVERS_MAX = 50
LEFTOVERS_MAX_SHARE = 0.10
LEFTOVERS_FEW = 5
_PAGE = 1000
_COPY_WAIT = timedelta(hours=1)
_UPLOAD_WAIT = timedelta(hours=24)


def withheld_paths(
    listing: MarketplaceListing,
    listings: MarketplaceListingRepository,
    vault: ListingPhotoVault,
) -> list[str]:
    """The photos of a hidden ad. Uploads older than the copies may be shown by another ad
    of the same seller too: that ad has its own check."""
    shown: set[str] = set()
    for other in listings.list_by_owner(listing.owner_id, _OWNER_LISTINGS):
        if other.id != listing.id and other.status in ("active", "reserved"):
            shown.update(vault.paths(other))
    return [path for path in vault.paths(listing) if path not in shown]


def move_photos(
    listing: MarketplaceListing,
    listings: MarketplaceListingRepository,
    vault: ListingPhotoVault,
) -> None:
    """Out of the public bucket while the ad is hidden, back when it is not. Whatever the
    storage does, the state of the ad stands: the hourly job tries again."""
    try:
        if listing.status in HIDDEN:
            vault.withhold(withheld_paths(listing, listings, vault))
        else:
            vault.release(vault.paths(listing))
    except Exception as exc:
        logger.warning("listing photos not moved yet: %s", type(exc).__name__)


class PruneRemovedListingsOutput(BaseModel):
    ran_at: datetime
    listings_deleted: int = 0
    photos_deleted: int = 0
    decisions_deleted: int = 0
    # False until the SQL script has run: the hourly job must not go red before.
    table_available: bool = True
    # Photos without an ad, and True when they were too many to be believed: nothing of
    # them was deleted, someone has to look.
    leftovers: int = 0
    leftovers_blocked: bool = False


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

    def run(
        self, now: datetime | None = None, *, allow_leftovers: int = 0
    ) -> PruneRemovedListingsOutput:
        """[allow_leftovers]: someone has looked at that many leftovers and they may go."""
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
        held = self._vault.held_files()
        public = self._vault.public_files()
        gone: set[str] = set()
        for listing, decided_at in self._removed_listings():
            if decided_at < moment - REMOVED_LISTING_RETENTION:
                # Files first: with the row gone nobody would know they are there.
                # The folder of the ad is enough, whatever the address in the row.
                folder = f"{PUBLISHED}/{listing.id}/"
                own = [i.path for i in (*held, *public) if i.path.startswith(folder)]
                shared = used_elsewhere(listing, self._vault, self._listings)
                paths = [path for path in self._vault.paths(listing) if path not in shared]
                paths = list(dict.fromkeys([*paths, *own]))
                output.photos_deleted += self._vault.purge(paths)
                gone.update(paths)
                self._listings.delete(listing.id)
                output.listings_deleted += 1
        for listing in self._listings.list_hidden(_HIDDEN_PER_RUN):
            if listing.updated_at < moment - _SETTLED:
                move_photos(listing, self._listings, self._vault)
        self._leftovers(
            [item for item in held if item.path not in gone],
            [item for item in public if item.path not in gone],
            moment,
            allow_leftovers,
            output,
        )
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

    def _leftovers(
        self,
        held: list[StoredPhoto],
        public: list[StoredPhoto],
        moment: datetime,
        allowed: int,
        output: PruneRemovedListingsOutput,
    ) -> None:
        """Photos held for an ad that is back return. Those of an ad that is gone (the
        installed apps delete it straight in the database), or taken off it, go for good;
        so do the uploads nobody published. There is no backup of the files: anything a row
        may mean is kept, and too many leftovers at once delete nothing."""
        shown: set[str] = set()
        meant: set[str] = set()
        recognised = False
        after = ""
        while page := self._listings.list_after(after, _PAGE):
            after = page[-1].id
            for listing in page:
                own = self._vault.paths(listing)
                recognised = recognised or bool(own)
                meant |= mentioned_paths(listing.photo_urls)
                if listing.status not in HIDDEN:
                    shown.update(own)

        self._vault.release([item.path for item in held if item.path in shown])
        useless = [item.path for item in held if item.path not in meant]
        for item in public:
            # A copy whose ad is being saved, an upload whose ad is being written.
            wait = _COPY_WAIT if item.path.startswith(f"{PUBLISHED}/") else _UPLOAD_WAIT
            if item.path not in meant and item.created_at < moment - wait:
                useless.append(item.path)

        output.leftovers = len(useless)
        files = len(held) + len(public)
        # There are ads with photos here and none is at the address in use.
        wrong_address = not recognised and bool(meant & {i.path for i in (*held, *public)})
        output.leftovers_blocked = wrong_address or (
            len(useless) > allowed
            and (
                len(useless) > LEFTOVERS_MAX
                or len(useless) > max(LEFTOVERS_FEW, files * LEFTOVERS_MAX_SHARE)
                # Every single file, while there are ads with photos.
                or (len(useless) == files and bool(meant))
            )
        )
        if output.leftovers_blocked:
            logger.error("too many leftover listing photos: nothing deleted")
            return
        output.photos_deleted += self._vault.purge(useless)
