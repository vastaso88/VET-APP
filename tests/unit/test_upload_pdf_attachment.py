"""PDF support for medical-record uploads (2026-10-04): text PDFs are
summarized from their text, scans through the vision model, and anything
that isn't a readable PDF within the limits is rejected before storage."""

import pytest
from fastapi.testclient import TestClient
from pdf_samples import JPEG_PAGE_SCAN, blank_pdf, scanned_pdf, text_pdf

from apps.api.main import app
from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.ports.pii_anonymizer import (
    PiiAnonymizationRequest,
    PiiAnonymizationResult,
)
from packages.core.application.services.document_summarizer import (
    DOCUMENT_SUMMARY_MARKER,
    DocumentSummarizer,
)
from packages.core.application.services.upload_chat_attachment import (
    UploadChatAttachmentInput,
    UploadChatAttachmentService,
)
from packages.core.domain.conversation.media_type import detect_media_type
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.documents.pypdf_reader import PypdfReader
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
    InMemoryPetProfileRepository,
)
from packages.shared.errors.base import ProviderError, ValidationError

REPORT_LINES = [
    "Clinica Veterinaria Esempio - Referto esami del 12/09/2026",
    "Proprietario: Mario Rossi, tel. 3331234567",
    "Creatinina: 2,4 mg/dL (rif. 0,5 - 1,5) ALTO",
    "Conclusioni: controllo della funzionalita renale tra 30 giorni.",
]


class _Storage:
    def __init__(self) -> None:
        self.saved: dict[str, bytes] = {}

    def save(self, key: str, content: bytes) -> None:
        self.saved[key] = content

    def read(self, key: str) -> bytes | None:
        return self.saved.get(key)


class _VisionAnalyzer:
    def __init__(self) -> None:
        self.images: list[bytes] = []

    def analyze(self, image_bytes: bytes, content_type: str, context: str) -> str:
        self.images.append(image_bytes)
        return f"Trascrizione pagina ({content_type}), contatto 3331234567"


class _SummaryLLM:
    """Echoes the document text it was given, so a test can see exactly
    what left for the provider."""

    def __init__(self, *, fail: bool = False) -> None:
        self.requests: list[LLMGenerationRequest] = []
        self._fail = fail

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        if self._fail:
            raise ProviderError("rate limited")
        return LLMResponse(
            content="Riassunto: " + request.user_prompt,
            provider="fake",
            model="fake-model",
            token_count=5,
        )


class _PhoneAnonymizer:
    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        return PiiAnonymizationResult(
            anonymized_text=request.text.replace("3331234567", "<TELEFONO>"), redaction_count=1
        )


def _service(
    llm: _SummaryLLM | None = None, max_bytes: int = 4_000_000
) -> tuple[UploadChatAttachmentService, _Storage, _VisionAnalyzer, _SummaryLLM]:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Rex", species="Cane"))
    storage = _Storage()
    vision = _VisionAnalyzer()
    llm = llm or _SummaryLLM()
    anonymizer = _PhoneAnonymizer()
    service = UploadChatAttachmentService(
        pets,
        InMemoryChatAttachmentRepository(),
        storage,
        vision,
        pdf_reader=PypdfReader(),
        document_summarizer=DocumentSummarizer(llm, anonymizer),
        pii_anonymizer=anonymizer,
        max_bytes=max_bytes,
    )
    return service, storage, vision, llm


def _upload(file_bytes: bytes, filename: str = "referto.pdf") -> UploadChatAttachmentInput:
    return UploadChatAttachmentInput(
        owner_id="owner-1",
        pet_id="pet-1",
        file_bytes=file_bytes,
        filename=filename,
        # What the mobile app declares for every file.
        content_type="application/octet-stream",
    )


def test_a_text_pdf_is_summarized_from_its_text_and_stored_as_a_pdf() -> None:
    service, storage, vision, llm = _service()
    pdf = text_pdf(REPORT_LINES)

    attachment = service.execute(_upload(pdf)).attachment

    assert attachment.content_type == "application/pdf"
    assert attachment.analysis_failed is False
    assert attachment.analysis is not None
    assert "Creatinina: 2,4 mg/dL" in attachment.analysis
    assert storage.read(attachment.storage_key) == pdf
    assert vision.images == []
    assert DOCUMENT_SUMMARY_MARKER in llm.requests[0].system_prompt


def test_personal_data_is_anonymized_before_the_provider_and_before_storage() -> None:
    service, _, _, llm = _service()

    attachment = service.execute(_upload(text_pdf(REPORT_LINES))).attachment

    assert "3331234567" not in llm.requests[0].user_prompt
    assert attachment.analysis is not None
    assert "3331234567" not in attachment.analysis


def test_a_scanned_pdf_is_read_through_the_vision_model() -> None:
    service, _, vision, llm = _service()

    attachment = service.execute(_upload(scanned_pdf())).attachment

    assert vision.images == [JPEG_PAGE_SCAN]
    assert llm.requests == []
    assert attachment.analysis is not None
    assert "Trascrizione pagina (image/jpeg)" in attachment.analysis
    assert "3331234567" not in attachment.analysis
    assert attachment.analysis_failed is False


def test_a_pdf_with_neither_text_nor_readable_scans_is_saved_without_analysis() -> None:
    service, storage, _, _ = _service()
    pdf = blank_pdf(2)

    attachment = service.execute(_upload(pdf)).attachment

    assert attachment.analysis is None
    assert attachment.analysis_failed is True
    assert storage.read(attachment.storage_key) == pdf


def test_the_pdf_is_saved_even_when_the_summary_provider_fails() -> None:
    service, storage, _, _ = _service(_SummaryLLM(fail=True))
    pdf = text_pdf(REPORT_LINES)

    attachment = service.execute(_upload(pdf)).attachment

    assert attachment.analysis_failed is True
    assert storage.read(attachment.storage_key) == pdf


def test_a_pdf_over_the_size_limit_is_rejected_and_not_stored() -> None:
    service, storage, _, _ = _service(max_bytes=200)

    with pytest.raises(ValidationError, match="attachment_too_large"):
        service.execute(_upload(text_pdf(REPORT_LINES)))

    assert storage.saved == {}


def test_a_non_pdf_file_with_a_pdf_extension_is_rejected() -> None:
    service, storage, _, _ = _service()

    with pytest.raises(ValidationError, match="unsupported_attachment_type"):
        service.execute(_upload(b"PK\x03\x04 this is really a zip archive", "referto.pdf"))

    assert storage.saved == {}


def test_a_pdf_with_too_many_pages_is_rejected_and_not_stored() -> None:
    service, storage, _, _ = _service()

    with pytest.raises(ValidationError, match="pdf_too_many_pages"):
        service.execute(_upload(blank_pdf(31)))

    assert storage.saved == {}


def test_a_password_protected_or_corrupt_pdf_is_rejected() -> None:
    service, storage, _, _ = _service()

    for broken in (blank_pdf(1, password="segreto"), b"%PDF-1.4\nnot really a pdf at all"):
        with pytest.raises(ValidationError, match="pdf_unreadable"):
            service.execute(_upload(broken))

    assert storage.saved == {}


def test_pdfs_are_rejected_when_the_deployment_has_no_pdf_support() -> None:
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Rex", species="Cane"))
    service = UploadChatAttachmentService(
        pets, InMemoryChatAttachmentRepository(), _Storage(), _VisionAnalyzer()
    )

    with pytest.raises(ValidationError, match="unsupported_attachment_type"):
        service.execute(_upload(text_pdf(REPORT_LINES)))


def test_media_type_detection_ignores_names_and_reads_signatures() -> None:
    assert detect_media_type(text_pdf(["x"])) == "application/pdf"
    assert detect_media_type(b"\xff\xd8\xff\xe0rest") == "image/jpeg"
    assert detect_media_type(b"RIFF\x00\x00\x00\x00WEBPVP8 ") == "image/webp"
    assert detect_media_type(b"x" * 2000 + b"%PDF- mentioned far too late") is None
    assert detect_media_type(b"") is None


def test_api_uploads_a_pdf_as_the_app_sends_it_and_serves_it_back() -> None:
    client = TestClient(app)
    created = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()
    pdf = text_pdf(REPORT_LINES)

    response = client.post(
        "/chat-attachments",
        data={"pet_id": created["pet_profile"]["id"]},
        files={"file": ("Referto esami à.pdf", pdf, "application/octet-stream")},
    )

    assert response.status_code == 200
    attachment = response.json()["attachment"]
    assert attachment["content_type"] == "application/pdf"
    assert attachment["analysis"]

    served = client.get(f"/chat-attachments/{attachment['id']}/file")

    assert served.status_code == 200
    assert served.headers["content-type"] == "application/pdf"
    assert "Referto%20esami%20%C3%A0.pdf" in served.headers["content-disposition"]
    assert served.content == pdf


def test_api_reports_a_fake_pdf_with_the_agreed_error_code() -> None:
    client = TestClient(app)
    created = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()

    response = client.post(
        "/chat-attachments",
        data={"pet_id": created["pet_profile"]["id"]},
        files={"file": ("referto.pdf", b"not a pdf", "application/pdf")},
    )

    assert response.status_code == 400
    assert response.json()["detail"].startswith("unsupported_attachment_type")
