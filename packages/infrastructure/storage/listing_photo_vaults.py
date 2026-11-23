"""The photos of Mercatino ads taken down by the team (ports/listing_photo_vault.py):
Supabase Storage, and an in-memory double for local runs and tests."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any
from urllib.parse import unquote

if TYPE_CHECKING:
    from supabase import Client

PUBLIC_BUCKET = "marketplace-photos"
# Private: no storage policy at all, so only the service role reaches it
# (scripts/setup/marketplace_content_review.sql).
HELD_BUCKET = "marketplace-photos-held"
SIGNED_URL_SECONDS = 600
_LIST_PAGE = 100
_MARKER = f"/object/public/{PUBLIC_BUCKET}/"


def own_paths(owner_id: str, photo_urls: list[str]) -> list[str]:
    """The links are text sent by the seller: only a file inside their own folder is
    ever touched, never someone else's."""
    paths: list[str] = []
    for url in photo_urls:
        _, found, tail = url.partition(_MARKER)
        path = unquote(tail.split("?")[0])
        parts = path.split("/")
        if found and owner_id and parts[0] == owner_id and len(parts) > 1:
            if all(part not in ("", ".", "..") for part in parts) and path not in paths:
                paths.append(path)
    return paths


class SupabaseListingPhotoVault:
    def __init__(self, client: Client) -> None:
        self._client = client

    def paths(self, owner_id: str, photo_urls: list[str]) -> list[str]:
        return own_paths(owner_id, photo_urls)

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
                path, content, {"content-type": "image/jpeg", "upsert": "true"}
            )
            # Last: a failure leaves a copy too many, never one too few.
            self._client.storage.from_(source).remove([path])

    def _exists(self, bucket: str, path: str) -> bool:
        folder, _, name = path.rpartition("/")
        entries: Any = self._client.storage.from_(bucket).list(
            folder, {"limit": _LIST_PAGE, "offset": 0, "search": name}
        )
        return any(entry["name"] == name for entry in entries or [])

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

    def held_paths(self) -> list[str]:
        return self._list_all("")

    def _list_all(self, prefix: str) -> list[str]:
        paths: list[str] = []
        offset = 0
        while True:
            entries: Any = self._client.storage.from_(HELD_BUCKET).list(
                prefix, {"limit": _LIST_PAGE, "offset": offset}
            )
            for entry in entries or []:
                path = f"{prefix}/{entry['name']}" if prefix else str(entry["name"])
                paths.extend(self._list_all(path) if entry.get("id") is None else [path])
            if len(entries or []) < _LIST_PAGE:
                return paths
            offset += _LIST_PAGE

    def purge(self, paths: list[str]) -> int:
        if paths:
            for bucket in (PUBLIC_BUCKET, HELD_BUCKET):
                self._client.storage.from_(bucket).remove(paths)
        return len(paths)


class InMemoryListingPhotoVault:
    def __init__(self) -> None:
        self.public: set[str] = set()
        self.held: set[str] = set()

    def paths(self, owner_id: str, photo_urls: list[str]) -> list[str]:
        return own_paths(owner_id, photo_urls)

    def withhold(self, paths: list[str]) -> None:
        for path in self.public & set(paths):
            self.held.add(path)
            self.public.discard(path)

    def release(self, paths: list[str]) -> None:
        for path in self.held & set(paths):
            self.public.add(path)
            self.held.discard(path)

    def signed_urls(self, paths: list[str]) -> list[str]:
        return [f"https://signed.example.com/{path}" for path in paths if path in self.held]

    def held_paths(self) -> list[str]:
        return sorted(self.held)

    def purge(self, paths: list[str]) -> int:
        self.public.difference_update(paths)
        self.held.difference_update(paths)
        return len(paths)
