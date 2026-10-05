from pydantic import BaseModel

from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.ports.pdf_reader import PdfContent, PdfReader
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.pii_anonymizer import PiiAnonymizationRequest, PiiAnonymizer
from packages.core.application.services.document_summarizer import DocumentSummarizer
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.conversation.media_type import (
    IMAGE_TYPES,
    JPEG,
    PDF,
    detect_media_type,
)
from packages.shared.errors.base import ProviderError, ValidationError

# Vercel rejects a request body over 4.5 MB before it reaches this code, so
# a larger limit could never be honoured on the deployed backend.
DEFAULT_MAX_ATTACHMENT_BYTES = 4_000_000
DEFAULT_MAX_PDF_PAGES = 30
# Below this much extracted text a PDF is treated as a scan (a text PDF of
# a real document has far more; a scan typically has none, or a stray
# header stamp).
MIN_PDF_TEXT_CHARS = 80

_DOCUMENT_OR_PHOTO_CONTEXT = (
    "Se è una foto dell'animale o del suo ambiente, descrivi eventuali segni "
    "clinicamente rilevanti visibili. Se è un documento (referto, esame, ricetta, "
    "libretto), trascrivine il contenuto rilevante, compreso l'animale a cui si "
    "riferisce così come è scritto (nome, specie, età)."
)


class UploadChatAttachmentInput(BaseModel):
    owner_id: str
    pet_id: str
    file_bytes: bytes
    filename: str
    content_type: str
    # The signed-in owner's display name, when the account has one: it is
    # removed from the stored transcription.
    owner_display_name: str | None = None


class UploadChatAttachmentOutput(BaseModel):
    attachment: ChatAttachment


class UploadChatAttachmentService:
    """Photo or PDF attachment for a chat or a medical record (video
    deliberately out of scope: analyzing it would need frame extraction —
    a new dependency — plus one vision call per sampled frame).

    Analysis runs synchronously, at upload time, not when the message is
    later sent: the result is cached on the attachment so a slow or
    failed model call only affects this endpoint, never blocks sending
    the actual chat message (see SendChatMessageService, which just reads
    the cached `analysis`). The cached text is what the chat later reads
    instead of the file itself, so it is anonymized before it is stored.

    `pdf_reader`/`document_summarizer` are optional: without them this
    deployment accepts images only.
    """

    def __init__(
        self,
        pet_profile_repository: PetProfileRepository,
        attachment_repository: ChatAttachmentRepository,
        media_storage: MediaStorage,
        image_analyzer: ImageAnalyzer,
        *,
        pdf_reader: PdfReader | None = None,
        document_summarizer: DocumentSummarizer | None = None,
        pii_anonymizer: PiiAnonymizer | None = None,
        max_bytes: int = DEFAULT_MAX_ATTACHMENT_BYTES,
        max_pdf_pages: int = DEFAULT_MAX_PDF_PAGES,
    ) -> None:
        self._pet_profile_repository = pet_profile_repository
        self._attachment_repository = attachment_repository
        self._media_storage = media_storage
        self._image_analyzer = image_analyzer
        self._pdf_reader = pdf_reader
        self._document_summarizer = document_summarizer
        self._pii_anonymizer = pii_anonymizer
        self._max_bytes = max_bytes
        self._max_pdf_pages = max_pdf_pages

    def execute(self, data: UploadChatAttachmentInput) -> UploadChatAttachmentOutput:
        pet_profile = self._pet_profile_repository.get(data.pet_id)
        if pet_profile is None:
            raise ValidationError("pet_profile not found")
        if pet_profile.owner_id != data.owner_id:
            raise ValidationError("pet_profile does not belong to this owner")
        if len(data.file_bytes) > self._max_bytes:
            raise ValidationError(
                "attachment_too_large: il file supera il limite di "
                f"{self._max_bytes // 1_000_000} MB."
            )
        # Real-world finding (2026-10-04): the mobile app uploads every
        # file as application/octet-stream, so trusting the declared type
        # (as this used to) rejected every photo it ever sent. The type is
        # read from the file's own signature instead; `data.content_type`
        # and the file extension are deliberately ignored.
        media_type = detect_media_type(data.file_bytes)
        pdf_supported = self._pdf_reader is not None and self._document_summarizer is not None
        if media_type not in IMAGE_TYPES and not (media_type == PDF and pdf_supported):
            raise ValidationError(
                "unsupported_attachment_type: sono accettati solo immagini JPG, PNG, "
                "WEBP" + (" e documenti PDF." if pdf_supported else ".")
            )

        # Everything that can reject the file happens before it is stored.
        pdf_content = self._read_pdf(data.file_bytes) if media_type == PDF else None
        known_names = [data.owner_display_name] if data.owner_display_name else []

        attachment = ChatAttachment(
            owner_id=data.owner_id,
            pet_id=data.pet_id,
            storage_key="",
            content_type=media_type,
            original_filename=data.filename,
        )
        self._media_storage.save(attachment.id, data.file_bytes)
        attachment = attachment.model_copy(update={"storage_key": attachment.id})

        try:
            if pdf_content is not None:
                analysis = self._analyze_pdf(pdf_content, pet_profile.species, known_names)
            else:
                analysis = self._analyze_image(data.file_bytes, media_type, pet_profile.species)
        except ProviderError:
            # The file itself is still saved and usable — only the
            # analysis step degrades, the same fail-safe posture as every
            # other model call in this codebase on a provider error.
            analysis = None
        if analysis:
            attachment = attachment.model_copy(
                update={"analysis": self._anonymize(analysis, known_names)}
            )
        else:
            attachment = attachment.model_copy(update={"analysis_failed": True})

        return UploadChatAttachmentOutput(attachment=self._attachment_repository.save(attachment))

    def _read_pdf(self, content: bytes) -> PdfContent:
        assert self._pdf_reader is not None
        pdf_content = self._pdf_reader.read(content)
        if pdf_content.page_count > self._max_pdf_pages:
            raise ValidationError(
                f"pdf_too_many_pages: il PDF ha {pdf_content.page_count} pagine, "
                f"il massimo è {self._max_pdf_pages}."
            )
        return pdf_content

    def _analyze_image(self, content: bytes, media_type: str, species: str) -> str | None:
        return self._image_analyzer.analyze(
            content, media_type, context=f"Specie: {species}. {_DOCUMENT_OR_PHOTO_CONTEXT}"
        )

    def _analyze_pdf(
        self, pdf_content: PdfContent, species: str, known_names: list[str]
    ) -> str | None:
        assert self._document_summarizer is not None
        if len(pdf_content.text.strip()) >= MIN_PDF_TEXT_CHARS:
            return self._document_summarizer.summarize(pdf_content.text, species, known_names)
        # A scan: no text layer, so read the page images the same way a
        # photographed document is read.
        pages = [
            self._image_analyzer.analyze(
                image,
                JPEG,
                context=(
                    f"Specie: {species}. Pagina {index} di un documento scansionato: "
                    "trascrivine il contenuto rilevante."
                ),
            )
            for index, image in enumerate(pdf_content.page_images, start=1)
        ]
        return "\n".join(page for page in pages if page) or None

    def _anonymize(self, text: str, known_names: list[str]) -> str:
        if self._pii_anonymizer is None:
            return text
        return self._pii_anonymizer.anonymize(
            PiiAnonymizationRequest(text=text, known_person_names=known_names)
        ).anonymized_text
