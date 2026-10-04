from typing import Protocol

from pydantic import BaseModel, Field


class PiiAnonymizationRequest(BaseModel):
    text: str
    language: str = "it"
    # Names already known for this request (the signed-in owner's display
    # name), replaced wherever they appear. A targeted substitution of
    # known values, not name recognition.
    known_person_names: list[str] = Field(default_factory=list)


class PiiAnonymizationResult(BaseModel):
    anonymized_text: str
    redaction_count: int
    entity_types_found: list[str] = Field(default_factory=list)


class PiiAnonymizer(Protocol):
    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult: ...
