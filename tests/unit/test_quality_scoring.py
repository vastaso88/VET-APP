from packages.core.domain.knowledge.models import EvidenceSource
from packages.core.domain.knowledge.quality import QualityWeights, score_source


def _source(**overrides) -> EvidenceSource:
    base = dict(
        title="Example",
        tier="C",
        access_depth="C",
        clinical_domain="clinical",
        species="dog",
        year=2024,
    )
    base.update(overrides)
    return EvidenceSource(**base)


def test_higher_tier_scores_higher_methodological_quality() -> None:
    weights = QualityWeights(
        methodological_quality=1.0,
        case_relevance=0,
        species_match=0,
        recency=0,
        evidence_depth=0,
    )
    tier_a = score_source(
        _source(tier="A"), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )
    tier_c = score_source(
        _source(tier="C"), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )

    assert tier_a.composite_score > tier_c.composite_score


def test_exact_species_match_scores_higher_than_mismatch() -> None:
    weights = QualityWeights(
        methodological_quality=0, case_relevance=0, species_match=1.0, recency=0, evidence_depth=0
    )
    matching = score_source(
        _source(species="dog"), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )
    mismatched = score_source(
        _source(species="cat"), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )
    generic = score_source(
        _source(species="other"), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )

    assert matching.species_match == 1.0
    assert mismatched.species_match < generic.species_match < matching.species_match


def test_matching_clinical_domain_scores_higher_than_unrelated() -> None:
    weights = QualityWeights(
        methodological_quality=0, case_relevance=1.0, species_match=0, recency=0, evidence_depth=0
    )
    matching = score_source(
        _source(clinical_domain="nutrition"),
        requested_species="dog",
        requested_intent="nutrition_question",
        now_year=2024,
        weights=weights,
    )
    unrelated = score_source(
        _source(clinical_domain="behavior"),
        requested_species="dog",
        requested_intent="nutrition_question",
        now_year=2024,
        weights=weights,
    )

    assert matching.case_relevance > unrelated.case_relevance


def test_recent_evidence_scores_higher_than_old_evidence() -> None:
    weights = QualityWeights(
        methodological_quality=0, case_relevance=0, species_match=0, recency=1.0, evidence_depth=0
    )
    recent = score_source(
        _source(year=2023), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )
    old = score_source(
        _source(year=1990), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )

    assert recent.recency > old.recency


def test_undated_evidence_gets_a_neutral_recency_score_not_zero() -> None:
    weights = QualityWeights(
        methodological_quality=0, case_relevance=0, species_match=0, recency=1.0, evidence_depth=0
    )
    undated = score_source(
        _source(year=None), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )

    assert 0 < undated.recency < 1


def test_full_text_access_scores_higher_than_abstract_only() -> None:
    weights = QualityWeights(
        methodological_quality=0, case_relevance=0, species_match=0, recency=0, evidence_depth=1.0
    )
    full_text = score_source(
        _source(access_depth="A"), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )
    abstract_only = score_source(
        _source(access_depth="C"), requested_species="dog", requested_intent="clinical_question",
        now_year=2024, weights=weights,
    )

    assert full_text.evidence_depth > abstract_only.evidence_depth
