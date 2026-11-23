from unittest.mock import Mock

import pytest

from packages.infrastructure.storage.supabase_media_storage import SupabaseMediaStorage


@pytest.mark.parametrize(
    ("content", "content_type"),
    [
        (b"%PDF-1.7\n", "application/pdf"),
        (b"\xff\xd8\xff\xe0", "image/jpeg"),
        (b"\x89PNG\r\n\x1a\n", "image/png"),
        (b"RIFF\x00\x00\x00\x00WEBP", "image/webp"),
        (b"unknown bytes", "application/octet-stream"),
    ],
)
def test_upload_passes_detected_mime_to_storage(content: bytes, content_type: str) -> None:
    client = Mock()
    bucket = client.storage.from_.return_value
    storage = SupabaseMediaStorage(client, "chat-attachments")

    storage.save("attachment-id", content)

    client.storage.from_.assert_called_once_with("chat-attachments")
    bucket.upload.assert_called_once_with(
        "attachment-id", content, {"upsert": "true", "content-type": content_type}
    )
