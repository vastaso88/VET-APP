"""A bucket that refuses a file the code accepts breaks the upload only in production:
the fakes of the other tests accept everything (DB-8, docs/security/02_audit.md)."""

import re
from pathlib import Path

from packages.core.application.services.upload_chat_attachment import (
    DEFAULT_MAX_ATTACHMENT_BYTES,
)
from packages.core.domain.conversation.media_type import IMAGE_TYPES, PDF

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/setup/security_2026_10_26.sql"


def _attachments_bucket() -> str:
    sql = re.sub(r"--[^\n]*", "", SCRIPT.read_text(encoding="utf-8"))
    found = [part for part in sql.split(";") if "where id = 'chat-attachments'" in part]
    assert len(found) == 1
    return found[0]


def test_the_bucket_accepts_exactly_the_types_the_code_accepts() -> None:
    array = re.search(r"allowed_mime_types = array\[(.*?)\]", _attachments_bucket(), re.S)
    assert array is not None
    assert set(re.findall(r"'([^']+)'", array.group(1))) == {*IMAGE_TYPES, PDF}


def test_the_pet_photos_bucket_accepts_exactly_the_types_the_app_uploads() -> None:
    """Collaudo F34. The app writes this bucket straight to Storage with a Content-Type it
    chooses: image/jpeg (photos, thumbnails, avatar), video/mp4 or video/quicktime."""
    schema = Path(__file__).resolve().parents[2] / "scripts/setup/supabase_schema.sql"
    sql = re.sub(r"--[^\n]*", "", schema.read_text(encoding="utf-8"))
    found = [
        part
        for part in sql.split(";")
        if "where id = 'pet-photos'" in part and "allowed_mime_types" in part
    ]
    assert len(found) == 1
    array = re.search(r"allowed_mime_types = array\[(.*?)\]", found[0], re.S)
    assert array is not None
    accepted = set(re.findall(r"'([^']+)'", array.group(1)))
    assert accepted == {*IMAGE_TYPES, "video/mp4", "video/quicktime"}

    dart = (
        Path(__file__).resolve().parents[2]
        / "apps/mobile_app/lib/features/pets/domain/pet_video_rules.dart"
    ).read_text(encoding="utf-8")
    sent_by_the_app = set(re.findall(r"'(video/[a-z0-9.+-]+)'", dart))
    assert sent_by_the_app <= accepted, "the app sends a video type the bucket would refuse"


def test_the_bucket_holds_the_largest_file_the_code_accepts() -> None:
    limit = re.search(r"file_size_limit = (\d+)", _attachments_bucket())
    assert limit is not None
    assert int(limit.group(1)) >= DEFAULT_MAX_ATTACHMENT_BYTES
