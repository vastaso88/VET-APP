from pydantic import BaseModel, Field


class EvidenceSynthesis(BaseModel):
    """Structured output of the Evidence Synthesizer (spec v3 §27).

    The LLM's allowed veterinary knowledge comes only from this packet —
    it receives the Situation Model plus retrieved evidence and must sort
    what it can say into these buckets rather than returning one
    undifferentiated paragraph, so supported/uncertain/conflicting claims
    stay explicitly distinguishable instead of blurred together. Each
    string may carry a `[n]` citation marker referencing the numbered
    evidence list, verified the same way as the previous free-text answer
    (packages/core/domain/knowledge/answer_validation.py).

    This is an internal representation, not the owner-facing text —
    ResponseGenerator (packages/core/application/services/response_generator.py)
    turns it into the actual reply.
    """

    supported_claims: list[str] = Field(default_factory=list)
    uncertain_claims: list[str] = Field(default_factory=list)
    conflicting_evidence: list[str] = Field(default_factory=list)
    evidence_gaps: list[str] = Field(default_factory=list)
    safe_owner_actions: list[str] = Field(default_factory=list)
    monitoring_points: list[str] = Field(default_factory=list)
    referral_conditions: list[str] = Field(default_factory=list)

    def all_claim_text(self) -> str:
        """Every string field joined, for citation/absolute-claim
        validation over the whole synthesis in one pass."""
        return "\n".join(
            item
            for field in (
                self.supported_claims,
                self.uncertain_claims,
                self.conflicting_evidence,
                self.evidence_gaps,
                self.safe_owner_actions,
                self.monitoring_points,
                self.referral_conditions,
            )
            for item in field
        )

    def is_empty(self) -> bool:
        return not (self.supported_claims or self.uncertain_claims or self.conflicting_evidence)
