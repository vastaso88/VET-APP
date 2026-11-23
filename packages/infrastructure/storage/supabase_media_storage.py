from __future__ import annotations

from typing import TYPE_CHECKING

from packages.core.application.ports.media_storage import MediaStorage
from packages.core.domain.conversation.media_type import detect_media_type
from packages.shared.errors.base import ProviderError

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
        # Without a content type storage3 declares "text/plain", which the bucket
        # refuses (it accepts only images and PDF): the type comes from the file's
        # own signature, never from what the client said.
        content_type = detect_media_type(content) or "application/octet-stream"
        try:
            self._client.storage.from_(self._bucket).upload(
                key, content, {"content-type": content_type, "upsert": "true"}
            )
        except Exception as exc:
            raise ProviderError("attachment storage refused the file") from exc

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
