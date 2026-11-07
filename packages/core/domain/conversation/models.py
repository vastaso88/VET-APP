from datetime import datetime
from typing import Any

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


# Fields of Conversation that never leave the backend (see public_dump).
INTERNAL_CONVERSATION_FIELDS: frozenset[str] = frozenset(
    {
        "situation_model",
        "coverage_score",
        "state",
        "interview_turns_used",
        "medical_record_consent",
        "awaiting_medical_record_consent",
        "awaiting_safety_clarification",
        "safety_clarification_category",
    }
)


def public_message(message: ChatMessage) -> dict[str, Any]:
    return message.model_dump(exclude={"state_after"})


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

    def public_dump(self) -> dict[str, Any]:
        """The conversation as the API hands it to the owner's app: id, pet,
        title and the messages. The assistant's working state (situation
        model, coverage score, interview counters, pending-consent flags, the
        per-message `state_after` snapshot) stays server-side: the app never
        reads it and it is the assistant's data, not the owner's."""
        return self.model_dump(
            exclude={
                **{name: True for name in INTERNAL_CONVERSATION_FIELDS},
                "messages": {"__all__": {"state_after"}},
            }
        )

    def snapshot(self) -> ConversationSnapshot:
        return ConversationSnapshot.model_validate(
            self.model_dump(include=set(ConversationSnapshot.model_fields))
        )

    def restore(self, snapshot: ConversationSnapshot) -> None:
        for name in ConversationSnapshot.model_fields:
            setattr(self, name, getattr(snapshot, name))
