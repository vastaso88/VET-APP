import re
from dataclasses import dataclass
from datetime import date

from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.domain.conversation.request_kind import ANALYTES
from packages.core.domain.medical_record.models import ClinicalEvent

# A document's cached text summary is clipped to this many characters per
# record, so a long lab report can't crowd everything else out of the
# prompt (spec v3 §38, data minimization).
MAX_DOCUMENT_SUMMARY_CHARS = 1200

# When the owner asks to have a document explained, the chat needs the
# document itself, not an 800-character excerpt: a biochemistry panel is
# cut mid-table at that length.
MAX_EXPLAINED_DOCUMENT_CHARS = 3500
MAX_EXPLAINED_DOCUMENTS = 2

# Words in the owner's request -> words that identify the matching kind of
# document in a record's title or text.
_DOCUMENT_TOPICS: tuple[tuple[tuple[str, ...], tuple[str, ...]], ...] = (
    (("urin", "pipì"), ("urin",)),
    (("feci", "coprolog", "parassit", "giardia", "vermi"), ("feci", "coprolog")),
    (("ecograf",), ("ecograf",)),
    (("radiograf", "lastr", "raggi"), ("radiograf", "lastr")),
    (
        ("sangue", "emocromo", "ematic", "biochim", "ematochim"),
        ("sangue", "emocromo", "ematic", "biochim", "ematochim"),
    ),
)


@dataclass(frozen=True)
class RecordDocument:
    """One entry of the cartella clinica as the chat can use it."""

    title: str
    occurred_on: date
    description: str | None
    # The text read from the attached file, None when there is none.
    content: str | None
    has_file: bool

    @property
    def unreadable(self) -> bool:
        """A file is attached but its reading failed (or never ran)."""
        return self.has_file and not self.content

    @property
    def explainable(self) -> bool:
        return bool(self.content or self.description)

    def label(self) -> str:
        return f"«{self.title}» del {italian_date(self.occurred_on)}"


_MONTHS = (
    "gennaio",
    "febbraio",
    "marzo",
    "aprile",
    "maggio",
    "giugno",
    "luglio",
    "agosto",
    "settembre",
    "ottobre",
    "novembre",
    "dicembre",
)


def italian_date(value: date) -> str:
    return f"{value.day} {_MONTHS[value.month - 1]} {value.year}"


class MedicalRecordContextRetriever:
    """Selective, summarized access to a pet's clinical documents (spec v3
    §18): the orchestrator only reads content AFTER the owner has
    consented, and by default gets a short summary — never the full record
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
        events = self._sorted_events(pet_id)
        if not events:
            return None
        lines = [self._format_event(event) for event in events[: self._max_entries]]
        return "\n".join(lines)

    def documents_for_pet(self, pet_id: str) -> list[RecordDocument]:
        """Every record, most recent first, with the full text read from
        its file. Content — call only with the owner's consent."""
        return [self._to_document(event) for event in self._sorted_events(pet_id)]

    @staticmethod
    def select_for_request(documents: list[RecordDocument], request: str) -> list[RecordDocument]:
        """The documents a request like "spiegami l'esame delle urine" is
        about: those matching the kind it names, otherwise the most recent
        ones. `documents` most recent first."""
        lowered = request.lower()
        for request_words, document_words in _DOCUMENT_TOPICS:
            if not any(word in lowered for word in request_words):
                continue
            matching = [
                document
                for document in documents
                if any(
                    word in f"{document.title} {(document.content or '')[:200]}".lower()
                    for word in document_words
                )
            ]
            if matching:
                return matching[:MAX_EXPLAINED_DOCUMENTS]
        # "cosa significa la creatinina alta?": the documents that report
        # that value (name followed by a figure), not merely mention it.
        for analyte in ANALYTES:
            if analyte not in lowered:
                continue
            reported = re.compile(rf"{re.escape(analyte)}\s*(\([^)]*\))?\s*:?\s*[<>]?\s*\d")
            matching = [
                document
                for document in documents
                if document.content and reported.search(document.content.lower())
            ]
            if matching:
                return matching[:MAX_EXPLAINED_DOCUMENTS]
        return documents[:MAX_EXPLAINED_DOCUMENTS]

    def _sorted_events(self, pet_id: str) -> list[ClinicalEvent]:
        return sorted(
            self._repository.list_by_pet(pet_id),
            key=lambda event: (event.occurred_on, event.created_at),
            reverse=True,
        )

    def _to_document(self, event: ClinicalEvent) -> RecordDocument:
        content = self._document_text(event)
        if content and len(content) > MAX_EXPLAINED_DOCUMENT_CHARS:
            content = content[:MAX_EXPLAINED_DOCUMENT_CHARS].rstrip() + "…"
        return RecordDocument(
            title=event.title or "Documento",
            occurred_on=event.occurred_on,
            description=event.subtitle or event.summary,
            content=content,
            has_file=bool(event.attachment_id),
        )

    def _format_event(self, event: ClinicalEvent) -> str:
        # `subtitle` is what the app writes; `summary` is the column the
        # live table already had — either one describes the record.
        description = event.subtitle or event.summary
        detail = f": {description}" if description else ""
        dated = f" ({event.event_date.strftime('%d/%m/%Y')})" if event.event_date else ""
        line = f"- {event.title or 'Documento'}{dated}{detail}"
        content = self._document_summary(event)
        if content:
            line += f"\n  Contenuto del documento: {content}"
        elif event.attachment_id:
            # Said explicitly, so the chat never fills the gap by guessing
            # what an unread file contains.
            line += "\n  (file allegato, ma il suo contenuto non è stato letto)"
        return line

    def _document_text(self, event: ClinicalEvent) -> str | None:
        if self._attachment_repository is None or not event.attachment_id:
            return None
        attachment = self._attachment_repository.get(event.attachment_id)
        # Same pet only: an id pointing at another pet's file must never
        # leak that file's content into this pet's context.
        if attachment is None or attachment.pet_id != event.pet_id or not attachment.analysis:
            return None
        return attachment.analysis.strip()

    def _document_summary(self, event: ClinicalEvent) -> str | None:
        text = self._document_text(event)
        if text is None:
            return None
        summary = " ".join(text.split())
        if len(summary) > MAX_DOCUMENT_SUMMARY_CHARS:
            summary = summary[:MAX_DOCUMENT_SUMMARY_CHARS].rstrip() + "…"
        return summary
