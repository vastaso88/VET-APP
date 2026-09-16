from datetime import datetime

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.situation.models import SituationModel


class ChatMessage(BaseModel):
    id: str = Field(default_factory=new_id)
    role: str
    content: str
    created_at: datetime = Field(default_factory=utc_now)


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
