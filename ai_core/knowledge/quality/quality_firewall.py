from ai_core.knowledge.quality.confidence_model import (
    ContradictionAssessment,
    EvidenceEvaluation,
    EvidencePack,
    FirewallDecision,
)
from ai_core.knowledge.quality.contradiction_detector import ContradictionDetector
from ai_core.knowledge.quality.evidence_score import EvidenceScorer
from ai_core.knowledge.quality.hallucination_guard import HallucinationGuard
from ai_core.knowledge.quality.species_validator import SpeciesValidator
from ai_core.knowledge.quality.weak_evidence_filter import WeakEvidenceFilter
from packages.core.domain.knowledge.models import EvidenceSource


class QualityFirewall:
    def __init__(
        self,
        evidence_scorer: EvidenceScorer | None = None,
        contradiction_detector: ContradictionDetector | None = None,
        weak_evidence_filter: WeakEvidenceFilter | None = None,
        species_validator: SpeciesValidator | None = None,
        hallucination_guard: HallucinationGuard | None = None,
    ) -> None:
        self._evidence_scorer = evidence_scorer or EvidenceScorer()
        self._contradiction_detector = contradiction_detector or ContradictionDetector()
        self._weak_evidence_filter = weak_evidence_filter or WeakEvidenceFilter()
        self._species_validator = species_validator or SpeciesValidator()
        self._hallucination_guard = hallucination_guard or HallucinationGuard()

    def evaluate_evidence(self, evidence_pack: EvidencePack, minimum_tier: str = "B") -> FirewallDecision:
        contradiction = self._contradiction_detector.detect(evidence_pack)
        agreement_score = max(0.0, 1.0 - contradiction.confidence_downgrade)
        evaluations: list[EvidenceEvaluation] = []
        approved_sources: list[EvidenceSource] = []
        rejected_sources: list[EvidenceSource] = []

        for source in evidence_pack.sources:
            evaluation = self._evaluate_single_source(
                source=source,
                evidence_pack=evidence_pack,
                agreement_score=agreement_score,
                minimum_tier=minimum_tier,
            )
            evaluations.append(evaluation)
            if self._weak_evidence_filter.is_reliable(evaluation):
                approved_sources.append(source)
            else:
                rejected_sources.append(source)

        reasons = self._build_reasons(evidence_pack, approved_sources, contradiction, evaluations)
        request_more_info = self._missing_critical_context(evidence_pack)
        rejected = not approved_sources
        trigger_unknown = rejected or contradiction.safe_response_trigger
        approved = bool(approved_sources) and not trigger_unknown and not request_more_info
        downgraded = bool(approved_sources) and (contradiction.contradiction_flag or len(approved_sources) == 1)

        decision = FirewallDecision(
            approved=approved,
            downgraded=downgraded and not request_more_info,
            rejected=rejected,
            trigger_unknown_mode=trigger_unknown,
            request_more_info=request_more_info,
            overall_confidence=self._overall_confidence(approved_sources, evaluations, contradiction),
            approved_sources=approved_sources,
            rejected_sources=rejected_sources,
            evaluations=evaluations,
            contradiction_assessment=contradiction,
            reasons=reasons,
        )
        return decision

    def approve(self, evidence_pack: EvidencePack, minimum_tier: str = "B") -> FirewallDecision:
        return self.evaluate_evidence(evidence_pack, minimum_tier=minimum_tier)

    def downgrade(self, evidence_pack: EvidencePack, minimum_tier: str = "B") -> FirewallDecision:
        decision = self.evaluate_evidence(evidence_pack, minimum_tier=minimum_tier)
        decision.downgraded = True
        if decision.overall_confidence == "high":
            decision.overall_confidence = "medium"
        return decision

    def reject(self, evidence_pack: EvidencePack, minimum_tier: str = "B") -> FirewallDecision:
        decision = self.evaluate_evidence(evidence_pack, minimum_tier=minimum_tier)
        decision.approved = False
        decision.rejected = True
        decision.trigger_unknown_mode = True
        return decision

    def trigger_unknown_mode(self, evidence_pack: EvidencePack, minimum_tier: str = "B") -> FirewallDecision:
        return self.reject(evidence_pack, minimum_tier=minimum_tier)

    def can_generate_answer(self, decision: FirewallDecision) -> bool:
        return self._hallucination_guard.can_generate_answer(decision)

    def _evaluate_single_source(
        self,
        source: EvidenceSource,
        evidence_pack: EvidencePack,
        agreement_score: float,
        minimum_tier: str,
    ) -> EvidenceEvaluation:
        species_valid = self._species_validator.validate_species_match(source, evidence_pack.pet_species)
        recent_enough = self._weak_evidence_filter.is_recent(source)
        minimum_tier_met = self._weak_evidence_filter.meets_minimum_tier(source, minimum_tier)
        clinically_sufficient = self._weak_evidence_filter.has_clinical_detail(source)
        score = self._evidence_scorer.score(source, evidence_pack, agreement_score)
        rejection_reasons: list[str] = []
        if not species_valid:
            rejection_reasons.append("species_mismatch")
        if not recent_enough:
            rejection_reasons.append("outdated_evidence")
        if not minimum_tier_met:
            rejection_reasons.append("tier_below_threshold")
        if not clinically_sufficient:
            rejection_reasons.append("insufficient_clinical_detail")
        if score.final_score < 0.62:
            rejection_reasons.append("confidence_below_threshold")

        return EvidenceEvaluation(
            source=source,
            score=score,
            species_valid=species_valid,
            recent_enough=recent_enough,
            minimum_tier_met=minimum_tier_met,
            clinically_sufficient=clinically_sufficient,
            rejection_reasons=rejection_reasons,
        )

    @staticmethod
    def _missing_critical_context(evidence_pack: EvidencePack) -> bool:
        if not evidence_pack.required_context_fields:
            return False
        return any(field not in evidence_pack.available_context for field in evidence_pack.required_context_fields)

    @staticmethod
    def _build_reasons(
        evidence_pack: EvidencePack,
        approved_sources: list[EvidenceSource],
        contradiction: ContradictionAssessment,
        evaluations: list[EvidenceEvaluation],
    ) -> list[str]:
        reasons: list[str] = []
        if not evidence_pack.sources:
            reasons.append("no_evidence")
        if not approved_sources and evidence_pack.sources:
            reasons.append("no_reliable_evidence")
        if contradiction.contradiction_flag:
            reasons.extend(contradiction.contradiction_types)
        for evaluation in evaluations:
            reasons.extend(evaluation.rejection_reasons)
        return sorted(set(reasons))

    @staticmethod
    def _overall_confidence(
        approved_sources: list[EvidenceSource],
        evaluations: list[EvidenceEvaluation],
        contradiction: ContradictionAssessment,
    ) -> str:
        if not approved_sources:
            return "low"
        average_score = sum(
            evaluation.score.final_score for evaluation in evaluations if evaluation.source in approved_sources
        ) / len(approved_sources)
        adjusted = average_score - contradiction.confidence_downgrade
        if adjusted >= 0.85:
            return "high"
        if adjusted >= 0.67:
            return "medium"
        return "low"
