"""The photos of an ad, from the seller's folder to the copies other people see
(domain/marketplace/photos.py). Never an ad with half of its photos: the copies are made
all together before anything is saved, and go away if the saving fails."""

from __future__ import annotations

import logging
from collections.abc import Iterator
from contextlib import contextmanager
from uuid import NAMESPACE_URL, uuid5

from pydantic import BaseModel

from packages.core.application.ports.listing_photo_vault import (
    ListingPhotoVault,
    PhotoUnusableError,
)
from packages.core.application.ports.listing_review_repository import ListingReviewRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.core.domain.marketplace.photos import (
    LOCAL_PHOTO_BASE,
    PHOTO_POLICY_MESSAGE,
    PUBLISHED,
    photo_link,
    published_links,
    published_path,
    upload_path,
)
from packages.shared.errors.base import ContentRefusedError

logger = logging.getLogger(__name__)

_OWNER_LISTINGS = 1000


def photo_refused() -> ContentRefusedError:
    return ContentRefusedError(PHOTO_POLICY_MESSAGE, terms=[], code="photo_refused")


class PhotoPlan(BaseModel):
    """What the seller asked for, checked; nothing has been copied yet."""

    base: str
    # In the order of the ad: copies it already has and uploads still to be copied.
    paths: list[str]
    uploads: list[str]

    @property
    def links(self) -> list[str]:
        return [photo_link(path, self.base) for path in self.paths]


def plan_photos(
    links: list[str],
    owner_id: str,
    vault: ListingPhotoVault | None,
    current: MarketplaceListing | None = None,
) -> PhotoPlan:
    """Refuses the ad when any link is not one of its own copies or a photo in the
    seller's own folder."""
    base = vault.base if vault is not None else LOCAL_PHOTO_BASE
    own = published_links(current.photo_urls, current.id, base) if current else []
    paths: list[str] = []
    uploads: list[str] = []
    for link in links:
        upload = upload_path(link, owner_id, base)
        copy = published_path(link, current.id, base) if current is not None else None
        if copy is not None and photo_link(copy, base) not in own:
            copy = None
        path = copy or upload
        if path is None or vault is None:
            raise photo_refused()
        if path not in paths:
            paths.append(path)
            if copy is None:
                uploads.append(path)
    return PhotoPlan(base=base, paths=paths, uploads=uploads)


@contextmanager
def published(
    plan: PhotoPlan,
    listing_id: str,
    vault: ListingPhotoVault | None,
    listings: MarketplaceListingRepository,
) -> Iterator[list[str]]:
    """The links of the ad, with the copies made. If what follows fails, the copies go."""
    if vault is None or not plan.uploads:
        yield plan.links
        return
    try:
        copies = vault.publish(listing_id, plan.uploads)
    except PhotoUnusableError as exc:
        raise photo_refused() from exc
    made = dict(zip(plan.uploads, copies, strict=True))
    try:
        yield [photo_link(made.get(path, path), plan.base) for path in plan.paths]
    except Exception:
        _drop_unused(copies, listing_id, vault, listings)
        raise


def _drop_unused(
    copies: list[str],
    listing_id: str,
    vault: ListingPhotoVault,
    listings: MarketplaceListingRepository,
) -> None:
    """An error is not always a refusal: the row may have been written and the answer lost.
    When the row cannot be read either, the hourly job decides."""
    try:
        row = listings.get(listing_id)
    except Exception as exc:
        logger.warning("copies of listing photos left to the job: %s", type(exc).__name__)
        return
    used = set(vault.paths(row)) if row is not None else set()
    _quietly(vault, [path for path in copies if path not in used])


def clean_up(
    plan: PhotoPlan,
    vault: ListingPhotoVault | None,
    listings: MarketplaceListingRepository,
    *,
    before: MarketplaceListing | None,
    after: MarketplaceListing,
) -> None:
    """Once the ad is saved: the uploads that were copied and the photos taken off it."""
    if vault is None:
        return
    old = vault.paths(before) if before else []
    unused = dict.fromkeys([*plan.uploads, *old])
    if unused:
        kept = {*vault.paths(after), *used_elsewhere(after, vault, listings)}
        _quietly(vault, [path for path in unused if path not in kept])


def used_elsewhere(
    listing: MarketplaceListing,
    vault: ListingPhotoVault,
    listings: MarketplaceListingRepository,
) -> set[str]:
    """Uploads older than the copies may be shown by another ad of the same seller."""
    others = listings.list_by_owner(listing.owner_id, _OWNER_LISTINGS)
    return {path for other in others if other.id != listing.id for path in vault.paths(other)}


def _quietly(vault: ListingPhotoVault, paths: list[str]) -> None:
    try:
        vault.discard(paths)
    except Exception as exc:
        logger.warning("listing photos not deleted yet: %s", type(exc).__name__)


class DeleteListingService:
    """The seller deletes their ad: the row, then its photos, wherever they are."""

    def __init__(self, listings: MarketplaceListingRepository, vault: ListingPhotoVault) -> None:
        self._listings = listings
        self._vault = vault

    def execute(self, listing_id: str, owner_id: str) -> bool:
        listing = self._listings.get(listing_id)
        # Someone else's ad looks exactly like a missing one.
        if listing is None or listing.owner_id != owner_id:
            return False
        shared = used_elsewhere(listing, self._vault, self._listings)
        paths = [path for path in self._vault.paths(listing) if path not in shared]
        self._listings.delete(listing_id)
        try:
            self._vault.purge(paths)
        except Exception as exc:  # the hourly job finds them without their ad
            logger.warning("listing photos not deleted yet: %s", type(exc).__name__)
        return True


class ExistingPhotosOutput(BaseModel):
    listings: int = 0
    to_publish: int = 0
    photos: int = 0
    # Links to other sites or to other people's files: never shown, dropped with --apply.
    other_links: int = 0
    published: int = 0
    # Left exactly as they were: a photo is missing or is not a whole JPEG.
    failed: int = 0


class PublishExistingPhotosService:
    """Ads older than the copies (scripts/maintenance/publish_marketplace_photos.py).
    Counts only unless [apply]; one ad at a time, all its photos or none. The name of a copy
    depends only on its original, so a run that stopped anywhere is completed by the next."""

    def __init__(
        self,
        listings: MarketplaceListingRepository,
        reviews: ListingReviewRepository,
        vault: ListingPhotoVault,
    ) -> None:
        self._listings = listings
        self._reviews = reviews
        self._vault = vault

    def run(self, *, apply: bool = False, page: int = 200) -> ExistingPhotosOutput:
        output = ExistingPhotosOutput()
        after = ""
        while batch := self._listings.list_after(after, page):
            after = batch[-1].id
            for listing in batch:
                self._one(listing, output, apply)
        return output

    def _one(self, listing: MarketplaceListing, output: ExistingPhotosOutput, apply: bool) -> None:
        base = self._vault.base
        output.listings += 1
        paths = self._vault.paths(listing)
        uploads = [path for path in paths if published_path(path, listing.id, base) is None]
        output.other_links += len(listing.photo_urls) - len(paths)
        output.photos += len(uploads)
        if uploads:
            output.to_publish += 1
        if not apply:
            return
        if uploads and not self._copy(listing, uploads):
            output.failed += 1
            return
        # After the row, and at every run: a decision of the team compares the photos of the
        # check with those of the ad.
        for review in self._reviews.list_by_listings([listing.id]):
            links = self._moved(listing, review.photo_urls)
            if links != review.photo_urls:
                self._reviews.save(review.model_copy(update={"photo_urls": links}))
        if not uploads:
            return
        shared = used_elsewhere(listing, self._vault, self._listings)
        self._vault.discard([path for path in uploads if path not in shared])
        output.published += 1

    def _copy(self, listing: MarketplaceListing, uploads: list[str]) -> bool:
        hidden = listing.status in ("removed", "removed_policy")
        copies = [_copy_of(upload, listing.id) for upload in uploads]
        try:
            if hidden:
                self._vault.release(uploads)
            self._vault.publish(listing.id, uploads, copies)
        except Exception as exc:
            logger.warning("photos of one ad left as they were: %s", type(exc).__name__)
            if hidden:
                self._vault.withhold(uploads)
            return False
        if hidden:
            self._vault.withhold(copies)
        # If the answer is lost the copies stay: the next run, or the hourly job, ends it.
        try:
            self._listings.set_photos(listing.id, self._moved(listing, listing.photo_urls))
        except Exception:
            if hidden:
                self._vault.withhold(uploads)
            raise
        return True

    def _moved(self, listing: MarketplaceListing, links: list[str]) -> list[str]:
        """The same change for an ad and for its checks; other links are dropped."""
        base = self._vault.base
        result: list[str] = []
        for link in links:
            copy = published_path(link, listing.id, base)
            upload = upload_path(link, listing.owner_id, base)
            path = copy or (_copy_of(upload, listing.id) if upload else None)
            if path is not None:
                result.append(photo_link(path, base))
        return list(dict.fromkeys(result))


def _copy_of(upload: str, listing_id: str) -> str:
    return f"{PUBLISHED}/{listing_id}/{uuid5(NAMESPACE_URL, upload)}.jpg"
