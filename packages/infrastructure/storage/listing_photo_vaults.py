"""The files of Mercatino ads (ports/listing_photo_vault.py): Supabase Storage, and an
in-memory double for local runs and tests."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any

from packages.core.application.ports.listing_photo_vault import PhotoUnusableError, StoredPhoto
from packages.core.domain.common.entity import new_id
from packages.core.domain.conversation.media_privacy import strip_image_metadata
from packages.core.domain.conversation.media_type import JPEG
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.core.domain.marketplace.photos import (
    LOCAL_PHOTO_BASE,
    PHOTO_BUCKET,
    PHOTO_MAX_BYTES,
    PUBLISHED,
    photo_link,
    stored_paths,
)

if TYPE_CHECKING:
    from supabase import Client

PUBLIC_BUCKET = PHOTO_BUCKET
# Private: no storage policy at all, so only the service role reaches it
# (scripts/setup/marketplace_content_review.sql).
HELD_BUCKET = "marketplace-photos-held"
SIGNED_URL_SECONDS = 600
_LIST_PAGE = 100
_JPEG_SIGNATURE = b"\xff\xd8\xff"
_SCAN_MIN_BYTES = 2
# Seconds: a photo taken off an ad should not stay long in the caches on the way.
_CACHE_SECONDS = "300"
# At most six photos per ad, one request each way: in a row they would outlast the app.
_COPIES_AT_ONCE = 3


def new_published_path(listing_id: str) -> str:
    return f"{PUBLISHED}/{listing_id}/{new_id()}.jpg"


def clean_photo(content: bytes) -> bytes:
    """Anyone signed in can put any bytes in their own folder: the type is read from the
    file, the position and the other metadata of the phone do not go on, and what is left
    has to be a whole picture (the original is deleted afterwards)."""
    if len(content) > PHOTO_MAX_BYTES or not content.startswith(_JPEG_SIGNATURE):
        raise PhotoUnusableError
    cleaned = strip_image_metadata(content, JPEG)
    if not _is_whole_jpeg(cleaned):
        raise PhotoUnusableError
    return cleaned


def _is_whole_jpeg(content: bytes) -> bool:
    """A frame with a size, at least one scan with data in it, the end of the image."""
    if not content.startswith(_JPEG_SIGNATURE) or not content.endswith(b"\xff\xd9"):
        return False
    position, sized = 2, False
    while position + 4 <= len(content) and content[position] == 0xFF:
        marker = content[position + 1]
        length = int.from_bytes(content[position + 2 : position + 4], "big")
        end = position + 2 + length
        if length < 2 or end > len(content):
            return False
        if marker == 0xDA:
            return sized and len(content) - 2 - end >= _SCAN_MIN_BYTES
        if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
            height = int.from_bytes(content[position + 5 : position + 7], "big")
            width = int.from_bytes(content[position + 7 : position + 9], "big")
            sized = length >= 8 and height > 0 and width > 0
        position = end
    return False


class SupabaseListingPhotoVault:
    def __init__(self, client: Client, base: str) -> None:
        self._client = client
        self._base = base

    @property
    def base(self) -> str:
        return self._base

    def publish(
        self, listing_id: str, uploads: list[str], targets: list[str] | None = None
    ) -> list[str]:
        # Names given by the caller may be those of a run that stopped half-way.
        replace = "true" if targets is not None else "false"
        if targets is None:
            targets = [new_published_path(listing_id) for _ in uploads]
        if not uploads:
            return targets
        try:
            # Leaving the block waits for every copy, so none appears after the clean-up.
            with ThreadPoolExecutor(max_workers=_COPIES_AT_ONCE) as pool:
                for _ in pool.map(self._copy, uploads, targets, [replace] * len(targets)):
                    pass
        except Exception:
            self._client.storage.from_(PUBLIC_BUCKET).remove(targets)
            raise
        return targets

    def _copy(self, upload: str, target: str, replace: str) -> None:
        if not self._exists(PUBLIC_BUCKET, upload):
            raise PhotoUnusableError
        content = clean_photo(self._client.storage.from_(PUBLIC_BUCKET).download(upload))
        self._client.storage.from_(PUBLIC_BUCKET).upload(
            target,
            content,
            {"content-type": JPEG, "cache-control": _CACHE_SECONDS, "upsert": replace},
        )

    def paths(self, listing: MarketplaceListing) -> list[str]:
        return stored_paths(listing.photo_urls, listing.id, listing.owner_id, self._base)

    def discard(self, paths: list[str]) -> None:
        if paths:
            self._client.storage.from_(PUBLIC_BUCKET).remove(paths)

    def withhold(self, paths: list[str]) -> None:
        self._move(paths, PUBLIC_BUCKET, HELD_BUCKET)

    def release(self, paths: list[str]) -> None:
        self._move(paths, HELD_BUCKET, PUBLIC_BUCKET)

    def _move(self, paths: list[str], source: str, target: str) -> None:
        for path in paths:
            if not self._exists(source, path):
                continue
            content = self._client.storage.from_(source).download(path)
            self._client.storage.from_(target).upload(
                path,
                content,
                {"content-type": JPEG, "cache-control": _CACHE_SECONDS, "upsert": "true"},
            )
            # Last: a failure leaves a copy too many, never one too few.
            self._client.storage.from_(source).remove([path])

    def _exists(self, bucket: str, path: str) -> bool:
        folder, _, name = path.rpartition("/")
        entries: Any = self._client.storage.from_(bucket).list(
            folder, {"limit": _LIST_PAGE, "offset": 0, "search": name}
        )
        return any(entry["name"] == name for entry in entries or [])

    def public_urls(self, paths: list[str]) -> list[str]:
        return [photo_link(path, self._base) for path in paths]

    def signed_urls(self, paths: list[str]) -> list[str]:
        urls: list[str] = []
        for path in paths:
            try:
                response: Any = self._client.storage.from_(HELD_BUCKET).create_signed_url(
                    path, SIGNED_URL_SECONDS
                )
            except Exception:
                continue  # not held (yet): the team still sees the text
            url = response.get("signedURL") or response.get("signedUrl")
            if isinstance(url, str) and url:
                urls.append(url)
        return urls

    def public_files(self) -> list[StoredPhoto]:
        return self._list_all(PUBLIC_BUCKET, "")

    def held_files(self) -> list[StoredPhoto]:
        return self._list_all(HELD_BUCKET, "")

    def _list_all(self, bucket: str, prefix: str) -> list[StoredPhoto]:
        found: list[StoredPhoto] = []
        offset = 0
        while True:
            entries: Any = self._client.storage.from_(bucket).list(
                prefix, {"limit": _LIST_PAGE, "offset": offset}
            )
            for entry in entries or []:
                path = f"{prefix}/{entry['name']}" if prefix else str(entry["name"])
                if entry.get("id") is None:  # a folder
                    found.extend(self._list_all(bucket, path))
                else:
                    found.append(StoredPhoto(path, _created(entry.get("created_at"))))
            if len(entries or []) < _LIST_PAGE:
                return found
            offset += _LIST_PAGE

    def purge(self, paths: list[str]) -> int:
        if paths:
            for bucket in (PUBLIC_BUCKET, HELD_BUCKET):
                self._client.storage.from_(bucket).remove(paths)
        return len(paths)


def _created(value: object) -> datetime:
    """Unknown counts as just made: a file is never deleted for want of a date."""
    try:
        moment = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return datetime.now(UTC)
    return moment if moment.tzinfo else moment.replace(tzinfo=UTC)


class InMemoryListingPhotoVault:
    def __init__(self, base: str = LOCAL_PHOTO_BASE) -> None:
        self._base = base
        self.public: set[str] = set()
        self.held: set[str] = set()
        # Files not in here are old ones.
        self.created: dict[str, datetime] = {}

    @property
    def base(self) -> str:
        return self._base

    def publish(
        self, listing_id: str, uploads: list[str], targets: list[str] | None = None
    ) -> list[str]:
        if not set(uploads) <= self.public:
            raise PhotoUnusableError
        if targets is None:
            targets = [new_published_path(listing_id) for _ in uploads]
        self.public.update(targets)
        self.created.update(dict.fromkeys(targets, datetime.now(UTC)))
        return targets

    def paths(self, listing: MarketplaceListing) -> list[str]:
        return stored_paths(listing.photo_urls, listing.id, listing.owner_id, self._base)

    def discard(self, paths: list[str]) -> None:
        self.public.difference_update(paths)

    def withhold(self, paths: list[str]) -> None:
        moved = self.public & set(paths)
        self.held |= moved
        self.public -= moved

    def release(self, paths: list[str]) -> None:
        moved = self.held & set(paths)
        self.public |= moved
        self.held -= moved

    def public_urls(self, paths: list[str]) -> list[str]:
        return [photo_link(path, self._base) for path in paths]

    def signed_urls(self, paths: list[str]) -> list[str]:
        return [f"https://signed.example.com/{path}" for path in paths if path in self.held]

    def _files(self, paths: set[str]) -> list[StoredPhoto]:
        old = datetime.min.replace(tzinfo=UTC)
        return [StoredPhoto(path, self.created.get(path, old)) for path in sorted(paths)]

    def public_files(self) -> list[StoredPhoto]:
        return self._files(self.public)

    def held_files(self) -> list[StoredPhoto]:
        return self._files(self.held)

    def purge(self, paths: list[str]) -> int:
        self.public.difference_update(paths)
        self.held.difference_update(paths)
        return len(paths)
