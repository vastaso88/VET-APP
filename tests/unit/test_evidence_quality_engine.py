from packages.core.application.services.evidence_quality_engine import EvidenceQualityEngine
from packages.core.domain.knowledge.models import EvidenceSource


def _source(**overrides: object) -> EvidenceSource:
    base: dict[str, object] = dict(
        title="Example",
        tier="C",
        access_depth="C",
        clinical_domain="clinical",
        species="dog",
        year=2024,
    )
    base.update(overrides)
    return EvidenceSource.model_validate(base)


def test_ranks_higher_quality_sources_first() -> None:
    engine = EvidenceQualityEngine()
    weak = _source(title="Weak case report", tier="C", year=2005)
    strong = _source(title="Strong guideline", tier="A", year=2024)

    ranked = engine.rank_and_select(
        [weak, strong], species="dog", intent="clinical_question", max_results=2, now_year=2024
    )

    assert [source.title for source in ranked.sources] == ["Strong guideline", "Weak case report"]
    assert ranked.top_score > 0


def test_deduplicates_by_doi_before_ranking() -> None:
    engine = EvidenceQualityEngine()
    duplicate_a = _source(title="Same paper (v1)", doi="10.1/x")
    duplicate_b = _source(title="Same paper (v2)", doi="10.1/x")

    ranked = engine.rank_and_select(
        [duplicate_a, duplicate_b],
        species="dog",
        intent="clinical_question",
        max_results=5,
        now_year=2024,
    )

    assert len(ranked.sources) == 1


def test_falls_back_to_title_for_dedup_when_no_identifiers() -> None:
    engine = EvidenceQualityEngine()
    same_title_a = _source(title="Untitled study", doi=None, pmid=None)
    same_title_b = _source(title="Untitled study", doi=None, pmid=None)

    ranked = engine.rank_and_select(
        [same_title_a, same_title_b],
        species="dog",
        intent="clinical_question",
        max_results=5,
        now_year=2024,
    )

    assert len(ranked.sources) == 1


def test_respects_max_results() -> None:
    engine = EvidenceQualityEngine()
    sources = [_source(title=f"Paper {i}", doi=f"10.1/{i}") for i in range(10)]

    ranked = engine.rank_and_select(
        sources, species="dog", intent="clinical_question", max_results=3, now_year=2024
    )

    assert len(ranked.sources) == 3


def test_guarantees_at_least_one_high_authority_source_when_available() -> None:
    engine = EvidenceQualityEngine()
    # Five weak-but-perfectly-relevant sources would normally crowd out a
    # single, slightly-less-relevant but authoritative guideline.
    weak_sources = [
        _source(title=f"Weak {i}", tier="C", doi=f"10.1/w{i}", year=2024) for i in range(5)
    ]
    guideline = _source(
        title="Authoritative guideline", tier="A", doi="10.1/guideline", clinical_domain="general"
    )

    ranked = engine.rank_and_select(
        [*weak_sources, guideline],
        species="dog",
        intent="clinical_question",
        max_results=3,
        now_year=2024,
    )

    assert any(source.tier == "A" for source in ranked.sources)


def test_returns_empty_ranked_evidence_for_no_sources() -> None:
    engine = EvidenceQualityEngine()

    ranked = engine.rank_and_select(
        [], species="dog", intent="clinical_question", max_results=3, now_year=2024
    )

    assert ranked.sources == []
    assert ranked.top_score == 0.0
