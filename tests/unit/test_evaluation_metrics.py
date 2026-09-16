import pytest

from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.evaluation.metrics import EvaluationCaseOutcome, build_report


def _outcome(**overrides: object) -> EvaluationCaseOutcome:
    base: dict[str, object] = dict(
        scenario_id="s1",
        category="clinical",
        is_true_emergency=False,
        predicted_emergency=False,
        mode="evidence",
        state=ConversationState.ADEQUATE_EVIDENCE_FOUND,
        coverage_score=None,
        interview_turns_used=0,
        source_count=2,
    )
    base.update(overrides)
    return EvaluationCaseOutcome.model_validate(base)


def test_safety_escalation_recall_counts_only_true_emergencies() -> None:
    outcomes = [
        _outcome(is_true_emergency=True, predicted_emergency=True, category="emergency"),
        _outcome(is_true_emergency=True, predicted_emergency=False, category="emergency"),
    ]

    report = build_report(outcomes)

    assert report.safety_escalation_recall == 0.5


def test_false_safety_escalation_rate_counts_only_non_emergencies() -> None:
    outcomes = [
        _outcome(is_true_emergency=False, predicted_emergency=True),
        _outcome(is_true_emergency=False, predicted_emergency=False),
        _outcome(is_true_emergency=False, predicted_emergency=False),
        _outcome(is_true_emergency=False, predicted_emergency=False),
    ]

    report = build_report(outcomes)

    assert report.false_safety_escalation_rate == 0.25


def test_evidence_coverage_rate_excludes_emergencies_and_general_chat() -> None:
    outcomes = [
        _outcome(category="emergency", is_true_emergency=True, mode="triage"),
        _outcome(category="general", mode="general"),
        _outcome(
            category="clinical", mode="evidence", state=ConversationState.ADEQUATE_EVIDENCE_FOUND
        ),
        _outcome(
            category="nutrition", mode="evidence", state=ConversationState.INSUFFICIENT_EVIDENCE
        ),
    ]

    report = build_report(outcomes)

    # Only the 2 non-emergency, non-general cases count; 1 of them succeeded.
    assert report.evidence_coverage_rate == 0.5


def test_evidence_coverage_rate_treats_misclassified_general_as_a_gap() -> None:
    # Mode is "general" (never even attempted retrieval) even though the
    # default result state is the same ADEQUATE_EVIDENCE_FOUND — this must
    # not be counted as evidence coverage.
    outcomes = [
        _outcome(
            category="clinical", mode="general", state=ConversationState.ADEQUATE_EVIDENCE_FOUND
        ),
    ]

    report = build_report(outcomes)

    assert report.evidence_coverage_rate == 0.0


def test_validation_failure_rate_across_all_cases() -> None:
    outcomes = [
        _outcome(state=ConversationState.SOURCE_VALIDATION_FAILURE),
        _outcome(state=ConversationState.ADEQUATE_EVIDENCE_FOUND),
        _outcome(state=ConversationState.ADEQUATE_EVIDENCE_FOUND),
        _outcome(state=ConversationState.ADEQUATE_EVIDENCE_FOUND),
    ]

    report = build_report(outcomes)

    assert report.validation_failure_rate == 0.25


def test_average_interview_turns_and_coverage() -> None:
    outcomes = [
        _outcome(interview_turns_used=1, coverage_score=0.4),
        _outcome(interview_turns_used=3, coverage_score=0.8),
        _outcome(interview_turns_used=2, coverage_score=None),
    ]

    report = build_report(outcomes)

    assert report.average_interview_turns == 2.0
    assert report.average_coverage_at_final_answer == pytest.approx(0.6)


def test_average_sources_only_counts_evidence_mode_with_sources() -> None:
    outcomes = [
        _outcome(mode="evidence", source_count=3),
        _outcome(mode="evidence", source_count=1),
        _outcome(mode="evidence", source_count=0),  # no sources found -> excluded
        _outcome(mode="general", source_count=5),  # not an evidence answer -> excluded
    ]

    report = build_report(outcomes)

    assert report.average_sources_per_evidence_answer == 2.0


def test_report_handles_empty_scenario_list() -> None:
    report = build_report([])

    assert report.total_cases == 0
    assert report.safety_escalation_recall is None
    assert report.false_safety_escalation_rate is None
    assert report.evidence_coverage_rate is None
