from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.domain.medical_record.models import ClinicalEvent

# A document's cached text summary is clipped to this many characters per
# record, so a long lab report can't crowd everything else out of the
# prompt (spec v3 §38, data minimization).
MAX_DOCUMENT_SUMMARY_CHARS = 800


class MedicalRecordContextRetriever:
    """Selective, summarized access to a pet's clinical documents (spec v3
    §18): the orchestrator only calls `summarize_for_pet` AFTER the owner
    has consented, and it returns a short summary — never the full record
    — to keep the LLM prompt minimal (spec v3 §38, data minimization).

    When a record has an uploaded file (`ClinicalEvent.attachment_id`),
    the text summary produced once at upload time
    (`ChatAttachment.analysis`) is included, so the chat knows what the
    document says without re-reading the image on every turn.
    """

    def __init__(
        self,
        repository: ClinicalEventRepository,
        *,
        attachment_repository: ChatAttachmentRepository | None = None,
        max_entries: int = 3,
    ) -> None:
        self._repository = repository
        self._attachment_repository = attachment_repository
        self._max_entries = max_entries

    def count_for_pet(self, pet_id: str) -> int:
        """How many records exist — existence only, no content, so it is
        safe to call before consent (the chat uses it to say transparently
        that there are documents it is not allowed to read)."""
        return len(self._repository.list_by_pet(pet_id))

    def summarize_for_pet(self, pet_id: str) -> str | None:
        events = self._repository.list_by_pet(pet_id)
        if not events:
            return None
        recent = sorted(events, key=lambda event: event.created_at, reverse=True)[
            : self._max_entries
        ]
        lines = [self._format_event(event) for event in recent]
        return "\n".join(lines)

    def _format_event(self, event: ClinicalEvent) -> str:
        detail = f": {event.subtitle}" if event.subtitle else ""
        line = f"- {event.title}{detail}"
        content = self._document_summary(event)
        if content:
            line += f"\n  Contenuto del documento: {content}"
        return line

    def _document_summary(self, event: ClinicalEvent) -> str | None:
        if self._attachment_repository is None or not event.attachment_id:
            return None
        attachment = self._attachment_repository.get(event.attachment_id)
        # Same pet only: an id pointing at another pet's file must never
        # leak that file's content into this pet's context.
        if attachment is None or attachment.pet_id != event.pet_id or not attachment.analysis:
            return None
        summary = " ".join(attachment.analysis.split())
        if len(summary) > MAX_DOCUMENT_SUMMARY_CHARS:
            summary = summary[:MAX_DOCUMENT_SUMMARY_CHARS].rstrip() + "…"
        return summary
