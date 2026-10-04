from pydantic import BaseModel

from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.pii_anonymizer import PiiAnonymizationRequest, PiiAnonymizer
from packages.core.domain.feedback.models import ChatResponseReport, ChatResponseReportReason
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.shared.errors.base import ValidationError

# The stored snapshot exists to review what went wrong with a reply, not to
# archive the conversation: clip it (data minimisation).
MAX_REPORTED_ANSWER_CHARS = 4000
MAX_DETAILS_CHARS = 1000


def clip(text: str, limit: int) -> str:
    return text if len(text) <= limit else text[:limit].rstrip() + "…"


class ReportChatResponseInput(BaseModel):
    reporter_owner_id: str
    conversation_id: str
    message_id: str
    reason: ChatResponseReportReason = "other"
    details: str | None = None
    reporter_display_name: str | None = None


class ReportChatResponseOutput(BaseModel):
    report: ChatResponseReport


class ReportChatResponseService:
    """Stores a "segnala questa risposta" report with as little personal
    data as the review needs (docs/compliance/07_contributi_utenti.md):
    the reporter only as a keyed pseudonym, the reply and the owner's
    comment passed through the PII anonymizer and clipped.
    """

    def __init__(
        self,
        conversation_repository: ConversationRepository,
        report_repository: ChatResponseReportRepository,
        pii_anonymizer: PiiAnonymizer,
        pseudonym_salt: str,
    ) -> None:
        self._conversation_repository = conversation_repository
        self._report_repository = report_repository
        self._pii_anonymizer = pii_anonymizer
        self._pseudonym_salt = pseudonym_salt

    def execute(self, data: ReportChatResponseInput) -> ReportChatResponseOutput:
        conversation = self._conversation_repository.get(data.conversation_id)
        if conversation is None:
            raise ValidationError("conversation not found")
        if conversation.owner_id != data.reporter_owner_id:
            raise ValidationError("conversation does not belong to this owner")

        message = next((m for m in conversation.messages if m.id == data.message_id), None)
        if message is None:
            raise ValidationError("message not found in this conversation")
        if message.role != "assistant":
            # Reporting the app's own reply is the point; the owner's own
            # message has nothing to report.
            raise ValidationError("only an assistant reply can be reported")

        ref = reporter_ref(data.reporter_owner_id, self._pseudonym_salt)
        names = [data.reporter_display_name] if data.reporter_display_name else []
        already_reported = next(
            (
                report
                for report in self._report_repository.list_by_reporter(ref)
                if report.message_id == data.message_id
            ),
            None,
        )
        if already_reported is not None:
            # Same person, same reply: one report, not a second row.
            return ReportChatResponseOutput(report=already_reported)

        report = self._report_repository.save(
            ChatResponseReport(
                conversation_id=data.conversation_id,
                message_id=data.message_id,
                pet_id=conversation.pet_id,
                reporter_ref=ref,
                reason=data.reason,
                details=self._sanitize(data.details, MAX_DETAILS_CHARS, names),
                reported_answer=self._sanitize(message.content, MAX_REPORTED_ANSWER_CHARS, names)
                or "",
            )
        )
        return ReportChatResponseOutput(report=report)

    def _sanitize(self, text: str | None, limit: int, names: list[str]) -> str | None:
        if text is None:
            return None
        anonymized = self._pii_anonymizer.anonymize(
            PiiAnonymizationRequest(text=text, known_person_names=names)
        ).anonymized_text
        return clip(anonymized, limit)
