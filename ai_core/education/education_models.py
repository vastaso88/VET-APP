from pydantic import BaseModel, Field


class EducationBlock(BaseModel):
    title: str
    clinical_fact: str
    plain_explanation: str
    why_it_matters: str
    what_to_monitor: list[str] = Field(default_factory=list)
    when_to_worry: list[str] = Field(default_factory=list)
    prevention_tip: str | None = None


class EducationResponsePayload(BaseModel):
    blocks: list[EducationBlock] = Field(default_factory=list)
    monitoring_guidance: list[str] = Field(default_factory=list)
    prevention_tips: list[str] = Field(default_factory=list)
