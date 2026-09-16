from pydantic import BaseModel

from packages.core.domain.knowledge.models import EvidenceSource

_TIER_SCORES: dict[str, float] = {"A": 1.0, "B": 0.7, "C": 0.4, "D": 0.1}
_ACCESS_DEPTH_SCORES: dict[str, float] = {"A": 1.0, "B": 0.9, "C": 0.5, "D": 0.6}


class QualityWeights(BaseModel):
    """Relative importance of each evidence-quality dimension (spec v3 §24).

    `tier` doubles as our proxy for both "methodological_quality" and
    "source_authority" from the spec — we don't yet have a separate,
    real signal for journal/publisher authority (e.g. editorial vetting,
    citation metrics), so treating them as one dimension is an honest
    simplification rather than fabricated precision. Revisit if/when such
    a signal becomes available.
    """

    methodological_quality: float = 0.40
    case_relevance: float = 0.20
    species_match: float = 0.15
    recency: float = 0.15
    evidence_depth: float = 0.10


DEFAULT_QUALITY_WEIGHTS = QualityWeights()


class EvidenceQualityBreakdown(BaseModel):
    """Per-dimension transparency for one scored source (spec v3 §49:
    observability should be able to reconstruct *why* a source ranked
    where it did, not just the final number)."""

    source: EvidenceSource
    methodological_quality: float
    case_relevance: float
    species_match: float
    recency: float
    evidence_depth: float
    composite_score: float


def _methodological_quality_score(tier: str) -> float:
    return _TIER_SCORES.get(tier, _TIER_SCORES["C"])


def _species_match_score(source_species: str, requested_species: str) -> float:
    if source_species == requested_species:
        return 1.0
    if source_species == "other":
        return 0.6
    return 0.2


INTENT_TO_DOMAIN: dict[str, str] = {
    "clinical_question": "clinical",
    "nutrition_question": "nutrition",
    "behavior_question": "behavior",
    "preventive_care": "preventive",
}


def _case_relevance_score(source_domain: str, requested_intent: str) -> float:
    requested_domain = INTENT_TO_DOMAIN.get(requested_intent, "general")
    if source_domain == requested_domain:
        return 1.0
    if source_domain == "general" or requested_domain == "general":
        return 0.5
    return 0.2


def _recency_score(year: int | None, *, now_year: int, half_life_years: int = 12) -> float:
    if year is None:
        return 0.4  # undated evidence isn't worthless, just not freshness-scored
    age = max(0, now_year - year)
    return 0.5 ** (age / half_life_years)


def _evidence_depth_score(access_depth: str) -> float:
    return _ACCESS_DEPTH_SCORES.get(access_depth, _ACCESS_DEPTH_SCORES["C"])


def score_source(
    source: EvidenceSource,
    *,
    requested_species: str,
    requested_intent: str,
    now_year: int,
    weights: QualityWeights = DEFAULT_QUALITY_WEIGHTS,
) -> EvidenceQualityBreakdown:
    methodological_quality = _methodological_quality_score(source.tier)
    case_relevance = _case_relevance_score(source.clinical_domain, requested_intent)
    species_match = _species_match_score(source.species, requested_species)
    recency = _recency_score(source.year, now_year=now_year)
    evidence_depth = _evidence_depth_score(source.access_depth)

    weight_values = weights.model_dump()
    total_weight = sum(weight_values.values()) or 1.0
    composite = (
        weight_values["methodological_quality"] * methodological_quality
        + weight_values["case_relevance"] * case_relevance
        + weight_values["species_match"] * species_match
        + weight_values["recency"] * recency
        + weight_values["evidence_depth"] * evidence_depth
    ) / total_weight

    return EvidenceQualityBreakdown(
        source=source,
        methodological_quality=methodological_quality,
        case_relevance=case_relevance,
        species_match=species_match,
        recency=recency,
        evidence_depth=evidence_depth,
        composite_score=composite,
    )
