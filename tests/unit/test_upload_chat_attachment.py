import pytest

from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.services.upload_chat_attachment import (
    UploadChatAttachmentInput,
    UploadChatAttachmentService,
)
from packages.core.domain.conversation.media_privacy import strip_image_metadata
from packages.core.domain.conversation.media_type import JPEG
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
    InMemoryPetProfileRepository,
)
from packages.shared.errors.base import ProviderError, ValidationError

JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"fake-jpeg-body"
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"fake-png-body"


class _FakeMediaStorage(MediaStorage):
    def __init__(self) -> None:
        self.saved: dict[str, bytes] = {}

    def save(self, key: str, content: bytes) -> None:
        self.saved[key] = content

    def read(self, key: str) -> bytes | None:
        return self.saved.get(key)


class _FakeImageAnalyzer(ImageAnalyzer):
    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        return f"analisi: {context}"


class _FailingImageAnalyzer(ImageAnalyzer):
    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        raise ProviderError("vision model unavailable")


def _service(
    analyzer: ImageAnalyzer, max_bytes: int = 4_000_000
) -> tuple[UploadChatAttachmentService, _FakeMediaStorage]:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="owner-1", name="Milo", species="dog"))
    storage = _FakeMediaStorage()
    service = UploadChatAttachmentService(
        pet_repository, InMemoryChatAttachmentRepository(), storage, analyzer, max_bytes=max_bytes
    )
    return service, storage


def _upload(
    file_bytes: bytes = JPEG_BYTES,
    *,
    owner_id: str = "owner-1",
    filename: str = "zampa.jpg",
    content_type: str = "image/jpeg",
) -> UploadChatAttachmentInput:
    return UploadChatAttachmentInput(
        owner_id=owner_id,
        pet_id="pet-1",
        file_bytes=file_bytes,
        filename=filename,
        content_type=content_type,
    )


def test_uploads_and_analyzes_a_photo() -> None:
    service, storage = _service(_FakeImageAnalyzer())

    result = service.execute(_upload())

    assert result.attachment.analysis is not None
    assert "dog" in result.attachment.analysis
    assert result.attachment.analysis_failed is False
    assert result.attachment.content_type == "image/jpeg"
    assert storage.read(result.attachment.storage_key) == strip_image_metadata(JPEG_BYTES, JPEG)


def test_saves_the_photo_even_when_analysis_fails() -> None:
    service, storage = _service(_FailingImageAnalyzer())

    result = service.execute(_upload())

    assert result.attachment.analysis is None
    assert result.attachment.analysis_failed is True
    assert storage.read(result.attachment.storage_key) == strip_image_metadata(JPEG_BYTES, JPEG)


def test_rejects_a_pet_belonging_to_a_different_owner() -> None:
    service, _ = _service(_FakeImageAnalyzer())

    with pytest.raises(ValidationError):
        service.execute(_upload(owner_id="someone-else"))


def test_accepts_a_photo_declared_as_octet_stream_like_the_mobile_app_sends_it() -> None:
    # Real-world finding (2026-10-04): Dart's MultipartFile.fromBytes sends
    # application/octet-stream, and the declared type used to be the only
    # thing checked — so every photo from the real app was rejected.
    service, _ = _service(_FakeImageAnalyzer())

    result = service.execute(
        _upload(PNG_BYTES, filename="zampa.png", content_type="application/octet-stream")
    )

    assert result.attachment.content_type == "image/png"
    assert result.attachment.analysis is not None


def test_rejects_a_file_that_only_claims_to_be_an_image() -> None:
    service, storage = _service(_FakeImageAnalyzer())

    with pytest.raises(ValidationError, match="unsupported_attachment_type"):
        service.execute(_upload(b"MZ\x90\x00 not an image at all", filename="foto.jpg"))

    assert storage.saved == {}


def test_rejects_a_video() -> None:
    service, _ = _service(_FakeImageAnalyzer())

    with pytest.raises(ValidationError, match="unsupported_attachment_type"):
        service.execute(
            _upload(b"\x00\x00\x00\x18ftypmp42", filename="video.mp4", content_type="video/mp4")
        )


def test_rejects_a_file_over_the_size_limit() -> None:
    service, storage = _service(_FakeImageAnalyzer(), max_bytes=1000)

    with pytest.raises(ValidationError, match="attachment_too_large"):
        service.execute(_upload(JPEG_BYTES + b"x" * 1000, filename="grande.jpg"))

    assert storage.saved == {}
