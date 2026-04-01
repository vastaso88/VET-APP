from pydantic import BaseModel, Field

from packages.core.domain.knowledge.models import EvidenceSource


class EvidencePack(BaseModel):
    pet_species: str
    clinical_domain: str
    owner_question: str
    sources: list[EvidenceSource] = Field(default_factory=list)
    required_context_fields: list[str] = Field(default_factory=list)
    available_context: dict[str, str] = Field(default_factory=dict)


class EvidenceScore(BaseModel):
    source_score: float
    recency_score: float
    species_score: float
    domain_score: float
    agreement_score: float
    final_score: float


class EvidenceAgreement(BaseModel):
    agreement_score: float = 0.0
    supporting_sources: int = 0
    conflicting_sources: int = 0
    rationale: list[str] = Field(default_factory=list)


class EvidenceEvaluation(BaseModel):
    source: EvidenceSource
    score: EvidenceScore
    species_valid: bool
    recent_enough: bool
    minimum_tier_met: bool
    clinically_sufficient: bool
    rejection_reasons: list[str] = Field(default_factory=list)


class ContradictionAssessment(BaseModel):
    contradiction_flag: bool = False
    contradiction_types: list[str] = Field(default_factory=list)
    confidence_downgrade: float = 0.0
    safe_response_trigger: bool = False
    rationale: list[str] = Field(default_factory=list)


class FirewallDecision(BaseModel):
    approved: bool
    downgraded: bool = False
    rejected: bool = False
    trigger_unknown_mode: bool = False
    request_more_info: bool = False
    overall_confidence: str = "low"
    approved_sources: list[EvidenceSource] = Field(default_factory=list)
    rejected_sources: list[EvidenceSource] = Field(default_factory=list)
    evaluations: list[EvidenceEvaluation] = Field(default_factory=list)
    contradiction_assessment: ContradictionAssessment = Field(
        default_factory=ContradictionAssessment
    )
    reasons: list[str] = Field(default_factory=list)


class UnknownResponse(BaseModel):
    answer: str
    limitations: list[str] = Field(default_factory=list)
    recommended_action: str | None = None
