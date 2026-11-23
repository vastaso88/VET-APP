"""The attachment bucket accepts only images and PDF: every upload declares its real type.

Found by round 1 of the test network (23/11/2026): without a content type storage3 sends
"text/plain" and the bucket answers 415, so no attachment could be saved.
"""

from __future__ import annotations

from typing import Any

import pytest

from packages.infrastructure.storage.supabase_media_storage import SupabaseMediaStorage
from packages.shared.errors.base import ProviderError

JPEG = bytes([0xFF, 0xD8, 0xFF, 0xE0]) + bytes(16) + bytes([0xFF, 0xD9])
PNG = bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) + bytes(16)
WEBP = b"RIFF" + bytes(4) + b"WEBP" + bytes(16)
PDF = b"%PDF-1.7 sintetico"


class _Bucket:
    """Like the real bucket: 415 for a type outside its list."""

    allowed = frozenset({"image/jpeg", "image/png", "image/webp", "application/pdf"})

    def __init__(self) -> None:
        self.saved: dict[str, tuple[bytes, str]] = {}

    def upload(self, path: str, file: bytes, file_options: dict[str, str]) -> None:
        content_type = file_options.get("content-type", "text/plain;charset=UTF-8")
        if content_type not in self.allowed:
            raise RuntimeError(f"415 mime type {content_type} is not supported")
        self.saved[path] = (file, content_type)


class _Client:
    def __init__(self, bucket: _Bucket) -> None:
        self.storage: Any = self
        self._bucket = bucket

    def from_(self, name: str) -> _Bucket:
        assert name == "chat-attachments"
        return self._bucket


def _storage(bucket: _Bucket) -> SupabaseMediaStorage:
    client: Any = _Client(bucket)
    return SupabaseMediaStorage(client, "chat-attachments")


@pytest.mark.parametrize(
    ("content", "expected"),
    [
        (JPEG, "image/jpeg"),
        (PNG, "image/png"),
        (WEBP, "image/webp"),
        (PDF, "application/pdf"),
    ],
)
def test_every_accepted_file_is_saved_with_its_real_type(content: bytes, expected: str) -> None:
    bucket = _Bucket()
    _storage(bucket).save("a-1", content)
    assert bucket.saved["a-1"] == (content, expected)


def test_an_unknown_file_never_passes_as_text_and_the_refusal_is_a_provider_error() -> None:
    bucket = _Bucket()
    with pytest.raises(ProviderError) as refused:
        _storage(bucket).save("a-2", b"non so che cosa sia")
    assert bucket.saved == {}
    assert "text/plain" not in str(refused.value)
