from pydantic import BaseModel, Field


class LearningHistoryItem(BaseModel):
    topic: str
    last_seen_at: str | None = None
    confidence: str | None = None


class OwnerKnowledgeProfile(BaseModel):
    experience_level: str = "new_owner"
    communication_style: str = "simple"
    learning_history: list[LearningHistoryItem] = Field(default_factory=list)
