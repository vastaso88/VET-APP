"""The photos of an ad and who is shown which (docs/features/marketplace_messages.md).

* The app uploads a photo in the seller's own folder: "<owner>/<listing>/<photo>.jpg".
* When the ad is published, or its photos change, the backend copies it to
  "published/<listing id>/<name made here>.jpg" and deletes the original. Other people are
  shown those copies only."""

from __future__ import annotations

import re

PHOTO_BUCKET = "marketplace-photos"
PHOTO_LINK_MAX_LENGTH = 500
PHOTO_MAX_BYTES = 5_000_000
PHOTO_POLICY_MESSAGE = "Le foto di un annuncio si possono caricare solo dall'app."
# First folder of the copies. A literal, never an id: a row written straight into the
# database may choose any listing id, the seller's own id included.
PUBLISHED = "published"
# Without Supabase (local runs, tests) there is no storage: an address that never answers.
LOCAL_PHOTO_BASE = "https://storage.invalid"

_PREFIX = f"/storage/v1/object/public/{PHOTO_BUCKET}/"
# Three plain names: nothing to decode, no query, no "..".
_NAME = r"[A-Za-z0-9_-]+"
_PATH = re.compile(rf"(?P<first>{_NAME})/(?P<second>{_NAME})/{_NAME}\.jpg")


def is_plain_name(value: object) -> bool:
    """Safe as the name of a folder: the id of a row is not always one made by the backend."""
    return isinstance(value, str) and re.fullmatch(_NAME, value) is not None


def mentioned_paths(links: list[str]) -> set[str]:
    """Every file a row may mean, whatever the address before it: only to PROTECT files from
    being deleted (the address of the storage may change), never to show or move them."""
    found: set[str] = set()
    for link in links:
        _, marker, tail = link.rpartition(f"/{PHOTO_BUCKET}/")
        found.add((tail if marker else link).split("?")[0])
    return found


def photo_base(supabase_url: str) -> str:
    return supabase_url.strip().rstrip("/") or LOCAL_PHOTO_BASE


def photo_link(path: str, base: str) -> str:
    return f"{base}{_PREFIX}{path}"


def _match(link: str, base: str) -> tuple[str, re.Match[str]] | None:
    path = link.removeprefix(base + _PREFIX) if link.startswith(base + _PREFIX) else link
    match = _PATH.fullmatch(path)
    return (path, match) if match is not None else None


def upload_path(link: str, owner_id: str, base: str) -> str | None:
    """The path of a photo uploaded by [owner_id], from its link or already a path; None
    for anything else (another site, another owner, data:, http:, "..", a query)."""
    found = _match(link, base)
    if found is None or not owner_id or owner_id == PUBLISHED:
        return None
    path, match = found
    return path if match["first"] == owner_id else None


def published_path(link: str, listing_id: str, base: str) -> str | None:
    """The path of a copy made for this very ad."""
    found = _match(link, base)
    if found is None or not listing_id:
        return None
    path, match = found
    return path if match["first"] == PUBLISHED and match["second"] == listing_id else None


def published_links(links: list[str], listing_id: str, base: str) -> list[str]:
    """What other people may be shown of an ad, whatever its row holds."""
    paths = [published_path(link, listing_id, base) for link in links]
    return [photo_link(path, base) for path in dict.fromkeys(paths) if path is not None]


def stored_paths(links: list[str], listing_id: str, owner_id: str, base: str) -> list[str]:
    """The files behind an ad: the copies and, on an ad older than them, the seller's own
    uploads. Anything else is left out, so it is never moved or deleted."""
    paths = [
        published_path(link, listing_id, base) or upload_path(link, owner_id, base)
        for link in links
    ]
    return [path for path in dict.fromkeys(paths) if path is not None]


def owner_links(links: list[str], listing_id: str, owner_id: str, base: str) -> list[str]:
    """What the seller is shown of their own ad: without the old uploads, editing an ad
    older than the copies would lose its photos."""
    return [photo_link(path, base) for path in stored_paths(links, listing_id, owner_id, base)]
