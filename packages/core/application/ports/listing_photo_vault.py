from datetime import datetime
from typing import NamedTuple, Protocol

from packages.core.domain.marketplace.models import MarketplaceListing


class PhotoUnusableError(Exception):
    """An upload that is missing, too big or not a JPEG."""


class StoredPhoto(NamedTuple):
    path: str
    created_at: datetime


class ListingPhotoVault(Protocol):
    """The files of the ads: the sellers' uploads, the copies other people see and, for an
    ad that is hidden, the private place where they wait for a review."""

    @property
    def base(self) -> str: ...

    def publish(
        self, listing_id: str, uploads: list[str], targets: list[str] | None = None
    ) -> list[str]:
        """Copies the uploads where no account can write, checked and without metadata;
        the paths of the copies, in the same order ([targets] when given, replacing what
        is there). All of them or none: on any failure nothing is left behind."""
        ...

    def paths(self, listing: MarketplaceListing) -> list[str]:
        """The files behind the ad, and nothing that is not its own."""
        ...

    def discard(self, paths: list[str]) -> None:
        """Deletes public files (uploads already copied, photos taken off an ad)."""
        ...

    def withhold(self, paths: list[str]) -> None:
        """Public to private. A file that is not public any more is skipped."""
        ...

    def release(self, paths: list[str]) -> None:
        """Private to public, after an accepted review. A file not held is skipped."""
        ...

    def public_urls(self, paths: list[str]) -> list[str]: ...

    def signed_urls(self, paths: list[str]) -> list[str]:
        """Short links for the team to look at the files held."""
        ...

    def public_files(self) -> list[StoredPhoto]: ...

    def held_files(self) -> list[StoredPhoto]: ...

    def purge(self, paths: list[str]) -> int:
        """Deletes them for good, wherever they are; how many were asked for."""
        ...
