from datetime import UTC, datetime

from ai_core.knowledge.quality.confidence_model import EvidencePack, EvidenceScore
from packages.core.domain.knowledge.models import EvidenceSource

TIER_BASE_SCORES: dict[str, float] = {
    "A": 1.0,
    "B": 0.8,
    "C": 0.55,
    "D": 0.25,
}


class EvidenceScorer:
    def score(self, source: EvidenceSource, pack: EvidencePack, agreement_score: float) -> EvidenceScore:
        source_score = self._source_score(source)
        recency_score = self._recency_score(source)
        species_score = self._species_score(source, pack.pet_species)
        domain_score = self._domain_score(source, pack.clinical_domain)
        final_score = (
            0.35 * source_score
            + 0.20 * recency_score
            + 0.20 * species_score
            + 0.15 * domain_score
            + 0.10 * agreement_score
        )
        return EvidenceScore(
            source_score=round(source_score, 3),
            recency_score=round(recency_score, 3),
            species_score=round(species_score, 3),
            domain_score=round(domain_score, 3),
            agreement_score=round(agreement_score, 3),
            final_score=round(final_score, 3),
        )

    @staticmethod
    def _source_score(source: EvidenceSource) -> float:
        base = TIER_BASE_SCORES.get(source.tier, 0.2)
        return min(1.0, max(0.0, (base * 0.7) + (source.trust_score * 0.3)))

    @staticmethod
    def _recency_score(source: EvidenceSource) -> float:
        if source.year is None:
            return 0.4
        current_year = datetime.now(UTC).year
        age = max(0, current_year - source.year)
        if age <= 2:
            return 1.0
        if age <= 5:
            return 0.8
        if age <= 8:
            return 0.6
        if age <= 12:
            return 0.4
        return 0.2

    @staticmethod
    def _species_score(source: EvidenceSource, pet_species: str) -> float:
        if source.species == pet_species:
            return 1.0
        if source.species == "other":
            return 0.65
        return 0.1

    @staticmethod
    def _domain_score(source: EvidenceSource, clinical_domain: str) -> float:
        if source.clinical_domain == clinical_domain:
            return 1.0
        if source.clinical_domain in {"general", "clinical"}:
            return 0.7
        return 0.3
