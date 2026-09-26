import pytest

from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.services.upload_chat_attachment import (
    UploadChatAttachmentInput,
    UploadChatAttachmentService,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
    InMemoryPetProfileRepository,
)
from packages.shared.errors.base import ProviderError, ValidationError


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


def _service(analyzer: ImageAnalyzer) -> tuple[UploadChatAttachmentService, _FakeMediaStorage]:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(
        PetProfile(id="pet-1", owner_id="owner-1", name="Milo", species="dog")
    )
    storage = _FakeMediaStorage()
    service = UploadChatAttachmentService(
        pet_repository, InMemoryChatAttachmentRepository(), storage, analyzer
    )
    return service, storage


def test_uploads_and_analyzes_a_photo() -> None:
    service, storage = _service(_FakeImageAnalyzer())

    result = service.execute(
        UploadChatAttachmentInput(
            owner_id="owner-1",
            pet_id="pet-1",
            file_bytes=b"fake-jpeg-bytes",
            filename="zampa.jpg",
            content_type="image/jpeg",
        )
    )

    assert result.attachment.analysis is not None
    assert "dog" in result.attachment.analysis
    assert result.attachment.analysis_failed is False
    assert storage.read(result.attachment.storage_key) == b"fake-jpeg-bytes"


def test_saves_the_photo_even_when_analysis_fails() -> None:
    service, storage = _service(_FailingImageAnalyzer())

    result = service.execute(
        UploadChatAttachmentInput(
            owner_id="owner-1",
            pet_id="pet-1",
            file_bytes=b"fake-jpeg-bytes",
            filename="zampa.jpg",
            content_type="image/jpeg",
        )
    )

    assert result.attachment.analysis is None
    assert result.attachment.analysis_failed is True
    assert storage.read(result.attachment.storage_key) == b"fake-jpeg-bytes"


def test_rejects_a_pet_belonging_to_a_different_owner() -> None:
    service, _ = _service(_FakeImageAnalyzer())

    with pytest.raises(ValidationError):
        service.execute(
            UploadChatAttachmentInput(
                owner_id="someone-else",
                pet_id="pet-1",
                file_bytes=b"data",
                filename="a.jpg",
                content_type="image/jpeg",
            )
        )


def test_rejects_a_non_image_content_type() -> None:
    service, _ = _service(_FakeImageAnalyzer())

    with pytest.raises(ValidationError):
        service.execute(
            UploadChatAttachmentInput(
                owner_id="owner-1",
                pet_id="pet-1",
                file_bytes=b"data",
                filename="video.mp4",
                content_type="video/mp4",
            )
        )
