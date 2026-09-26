from pydantic import BaseModel

from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.shared.errors.base import ProviderError, ValidationError

_SUPPORTED_CONTENT_TYPE_PREFIX = "image/"


class UploadChatAttachmentInput(BaseModel):
    owner_id: str
    pet_id: str
    file_bytes: bytes
    filename: str
    content_type: str


class UploadChatAttachmentOutput(BaseModel):
    attachment: ChatAttachment


class UploadChatAttachmentService:
    """Photo attachment for a chat (video deliberately out of scope for
    now: analyzing it would need frame extraction — a new dependency —
    plus one vision call per sampled frame instead of one per photo,
    multiplying Groq usage for comparatively little benefit at this
    stage).

    Analysis runs synchronously, at upload time, not when the message is
    later sent: the result is cached on the attachment so a slow or
    failed vision call only affects this endpoint, never blocks sending
    the actual chat message (see SendChatMessageService, which just reads
    the cached `analysis`).
    """

    def __init__(
        self,
        pet_profile_repository: PetProfileRepository,
        attachment_repository: ChatAttachmentRepository,
        media_storage: MediaStorage,
        image_analyzer: ImageAnalyzer,
    ) -> None:
        self._pet_profile_repository = pet_profile_repository
        self._attachment_repository = attachment_repository
        self._media_storage = media_storage
        self._image_analyzer = image_analyzer

    def execute(self, data: UploadChatAttachmentInput) -> UploadChatAttachmentOutput:
        pet_profile = self._pet_profile_repository.get(data.pet_id)
        if pet_profile is None:
            raise ValidationError("pet_profile not found")
        if pet_profile.owner_id != data.owner_id:
            raise ValidationError("pet_profile does not belong to this owner")
        if not data.content_type.startswith(_SUPPORTED_CONTENT_TYPE_PREFIX):
            raise ValidationError("only image attachments are supported today")

        attachment = ChatAttachment(
            owner_id=data.owner_id,
            pet_id=data.pet_id,
            storage_key="",
            content_type=data.content_type,
            original_filename=data.filename,
        )
        self._media_storage.save(attachment.id, data.file_bytes)
        attachment = attachment.model_copy(update={"storage_key": attachment.id})

        try:
            analysis = self._image_analyzer.analyze(
                data.file_bytes,
                data.content_type,
                context=(
                    f"Specie: {pet_profile.species}. Descrivi eventuali segni "
                    "clinicamente rilevanti visibili nella foto."
                ),
            )
            attachment = attachment.model_copy(update={"analysis": analysis})
        except ProviderError:
            # The photo itself is still saved and usable — only the
            # visual-analysis step degrades, the same fail-safe posture
            # as every other LLM call in this codebase on a provider error.
            attachment = attachment.model_copy(update={"analysis_failed": True})

        return UploadChatAttachmentOutput(attachment=self._attachment_repository.save(attachment))
