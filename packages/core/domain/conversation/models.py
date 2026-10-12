from datetime import datetime

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.situation.models import SituationModel


class ConversationSnapshot(BaseModel):
    """The conversation's working state right after one assistant reply.

    Stored on that reply so that editing an earlier message (which drops
    everything after it) can put the state back exactly as it was at that
    point — the safety question being answered, the anamnesis so far, a
    consent being asked — instead of guessing it from the text."""

    situation_model: SituationModel | None = None
    coverage_score: float | None = None
    state: ConversationState = ConversationState.NEED_MORE_INFORMATION
    interview_turns_used: int = 0
    medical_record_consent: bool | None = None
    awaiting_medical_record_consent: bool = False
    awaiting_safety_clarification: bool = False
    safety_clarification_category: str | None = None


class ChatMessage(BaseModel):
    id: str = Field(default_factory=new_id)
    role: str
    content: str
    created_at: datetime = Field(default_factory=utc_now)
    # Set when the owner attached a photo to this turn (see
    # packages/core/domain/conversation/attachment.py) — lets the client
    # render the photo inline without a separate lookup call.
    attachment_id: str | None = None
    # The app's own id for a message the owner sent: a retry of the same
    # message carries it again, so the server can hand back the reply it
    # already produced instead of answering (and storing) it twice.
    client_message_id: str | None = None
    # On assistant messages: whether the text was written by the AI model
    # (drives the AI-disclosure badge) — kept so a replayed reply carries it.
    ai_generated: bool | None = None
    # On assistant messages: the conversation's state after this reply.
    state_after: ConversationSnapshot | None = None


class Conversation(BaseModel):
    id: str = Field(default_factory=new_id)
    owner_id: str
    pet_id: str
    title: str
    messages: list[ChatMessage] = Field(default_factory=list)
    situation_model: SituationModel | None = None
    coverage_score: float | None = None
    state: ConversationState = ConversationState.NEED_MORE_INFORMATION
    interview_turns_used: int = 0
    medical_record_consent: bool | None = None
    awaiting_medical_record_consent: bool = False
    awaiting_safety_clarification: bool = False
    safety_clarification_category: str | None = None

    def snapshot(self) -> ConversationSnapshot:
        return ConversationSnapshot.model_validate(
            self.model_dump(include=set(ConversationSnapshot.model_fields))
        )

    def restore(self, snapshot: ConversationSnapshot) -> None:
        for name in ConversationSnapshot.model_fields:
            setattr(self, name, getattr(snapshot, name))
