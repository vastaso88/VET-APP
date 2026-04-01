from datetime import UTC, datetime

from ai_core.knowledge.quality.confidence_model import EvidenceEvaluation
from packages.core.domain.knowledge.models import EvidenceSource

MINIMUM_TIER_ORDER: dict[str, int] = {"D": 0, "C": 1, "B": 2, "A": 3}


class WeakEvidenceFilter:
    def __init__(self, minimum_score: float = 0.62, maximum_age_years: int = 10) -> None:
        self._minimum_score = minimum_score
        self._maximum_age_years = maximum_age_years

    def is_reliable(self, evaluation: EvidenceEvaluation) -> bool:
        return (
            evaluation.score.final_score >= self._minimum_score
            and evaluation.minimum_tier_met
            and evaluation.species_valid
            and evaluation.recent_enough
            and evaluation.clinically_sufficient
        )

    def meets_minimum_tier(self, source: EvidenceSource, minimum_tier: str = "B") -> bool:
        return MINIMUM_TIER_ORDER.get(source.tier, -1) >= MINIMUM_TIER_ORDER.get(minimum_tier, 0)

    def is_species_valid(self, species_valid: bool) -> bool:
        return species_valid

    def is_recent(self, source: EvidenceSource) -> bool:
        if source.year is None:
            return False
        return (datetime.now(UTC).year - source.year) <= self._maximum_age_years

    @staticmethod
    def has_clinical_detail(source: EvidenceSource) -> bool:
        snippet = (source.snippet or "").strip()
        return len(snippet.split()) >= 8 and any(
            marker in snippet.lower()
            for marker in ("monitor", "assessment", "risk", "hydration", "sign", "symptom")
        )
