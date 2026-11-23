from __future__ import annotations

from typing import TYPE_CHECKING

from packages.core.application.ports.media_storage import MediaStorage
from packages.core.domain.conversation.media_type import detect_media_type

if TYPE_CHECKING:
    from supabase import Client


class SupabaseMediaStorage(MediaStorage):
    """Chat/medical-record attachment bytes stored in a Supabase Storage
    bucket. Required on serverless deployments (Vercel): the filesystem
    there is read-only/ephemeral, so `LocalFileStorage` cannot be used in
    production. `key` is always an id this codebase generates itself
    (ChatAttachment.id, from new_id()), never raw user input.
    """

    def __init__(self, client: Client, bucket: str) -> None:
        self._client = client
        self._bucket = bucket

    def save(self, key: str, content: bytes) -> None:
        # Storage validates the MIME against the bucket allowlist. The SDK's
        # text/plain default would reject supported photos and PDF documents.
        content_type = detect_media_type(content) or "application/octet-stream"
        self._client.storage.from_(self._bucket).upload(
            key, content, {"upsert": "true", "content-type": content_type}
        )

    def delete(self, key: str) -> None:
        try:
            self._client.storage.from_(self._bucket).remove([key])
        except Exception:
            # Already gone, or the bucket is unreachable right now: the
            # retention job runs again tomorrow (and logs its own counts).
            return

    def read(self, key: str) -> bytes | None:
        try:
            return self._client.storage.from_(self._bucket).download(key)
        except Exception:
            # storage3 raises its own API-error type for a missing object;
            # any failure here means "not found" from the caller's view,
            # matching LocalFileStorage.read's None-on-missing contract.
            return None
