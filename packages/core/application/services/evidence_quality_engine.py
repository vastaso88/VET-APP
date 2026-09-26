from datetime import UTC, datetime

from pydantic import BaseModel

from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.knowledge.quality import (
    DEFAULT_QUALITY_WEIGHTS,
    EvidenceQualityBreakdown,
    QualityWeights,
    score_source,
)


class RankedEvidence(BaseModel):
    sources: list[EvidenceSource]
    top_score: float
    breakdowns: list[EvidenceQualityBreakdown]


class EvidenceQualityEngine:
    """Scores, deduplicates and selects the final evidence set for a case
    (spec v3 §24-25, §5 selection rules) — applied uniformly after any
    EvidenceRetriever, so individual retrievers stay focused on fetching.
    """

    def __init__(self, *, weights: QualityWeights = DEFAULT_QUALITY_WEIGHTS) -> None:
        self._weights = weights

    def rank_and_select(
        self,
        sources: list[EvidenceSource],
        *,
        species: str,
        intent: str,
        max_results: int,
        now_year: int | None = None,
    ) -> RankedEvidence:
        year = now_year if now_year is not None else datetime.now(UTC).year
        deduped = self._deduplicate(sources)
        breakdowns = [
            score_source(
                source,
                requested_species=species,
                requested_intent=intent,
                now_year=year,
                weights=self._weights,
            )
            for source in deduped
        ]
        breakdowns.sort(key=lambda breakdown: breakdown.composite_score, reverse=True)
        selected = self._select_diverse(breakdowns, max_results)
        return RankedEvidence(
            sources=[breakdown.source for breakdown in selected],
            top_score=selected[0].composite_score if selected else 0.0,
            breakdowns=selected,
        )

    @staticmethod
    def _deduplicate(sources: list[EvidenceSource]) -> list[EvidenceSource]:
        seen: set[str] = set()
        deduped: list[EvidenceSource] = []
        for source in sources:
            key = source.doi or source.pmid or source.title
            if key in seen:
                continue
            seen.add(key)
            deduped.append(source)
        return deduped

    @staticmethod
    def _select_diverse(
        ranked: list[EvidenceQualityBreakdown], max_results: int
    ) -> list[EvidenceQualityBreakdown]:
        if max_results <= 0 or not ranked:
            return []
        selected = ranked[:max_results]
        has_high_authority = any(b.source.tier in ("A", "B") for b in selected)
        if not has_high_authority:
            best_high_authority = next(
                (b for b in ranked[max_results:] if b.source.tier in ("A", "B")), None
            )
            if best_high_authority is not None:
                selected = [*selected[:-1], best_high_authority]
        return selected
