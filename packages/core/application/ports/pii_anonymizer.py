from typing import Protocol

from pydantic import BaseModel, Field


class PiiAnonymizationRequest(BaseModel):
    text: str
    language: str = "it"


class PiiAnonymizationResult(BaseModel):
    anonymized_text: str
    redaction_count: int
    entity_types_found: list[str] = Field(default_factory=list)


class PiiAnonymizer(Protocol):
    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult: ...
