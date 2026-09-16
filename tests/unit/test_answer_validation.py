from packages.core.domain.knowledge.answer_validation import validate_answer


def test_valid_answer_with_in_range_citations_passes() -> None:
    result = validate_answer(
        "Secondo le fonti [1] e [2], conviene monitorare la situazione.", sources_count=2
    )

    assert result.is_valid
    assert result.cited_indexes == [1, 2]


def test_out_of_range_citation_is_a_violation() -> None:
    result = validate_answer("Come riportato in [3], questo è normale.", sources_count=2)

    assert not result.is_valid
    assert any("citation_out_of_range" in v for v in result.violations)


def test_citation_with_zero_sources_is_always_invalid() -> None:
    result = validate_answer("Vedi [1] per approfondire.", sources_count=0)

    assert not result.is_valid


def test_answer_without_citations_is_valid_when_none_are_expected() -> None:
    result = validate_answer(
        "In generale conviene osservare appetito e idratazione.", sources_count=0
    )

    assert result.is_valid
    assert result.cited_indexes == []


def test_absolute_claim_marker_is_a_violation() -> None:
    result = validate_answer(
        "Questo trattamento è garantito al 100% e risolve sempre il problema.", sources_count=1
    )

    assert not result.is_valid
    assert any("unsupported_absolute_claim" in v for v in result.violations)


def test_ordinary_percentage_language_is_not_flagged() -> None:
    # Only compound absolute-claim phrases are flagged, not any bare "%",
    # since legitimate statistics ("80% dei casi migliora...") are normal
    # in real evidence-grounded answers.
    result = validate_answer(
        "Gli studi riportano un miglioramento nell'80% dei casi trattati precocemente.",
        sources_count=1,
    )

    assert result.is_valid
