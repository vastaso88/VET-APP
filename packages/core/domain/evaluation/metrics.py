from pydantic import BaseModel

from packages.core.domain.conversation.states import ConversationState


class EvaluationCaseOutcome(BaseModel):
    """What actually happened for one scenario, alongside its ground-truth
    label — the raw material the Beta metrics (spec v3 §42-43) are computed
    from."""

    scenario_id: str
    category: str
    is_true_emergency: bool
    predicted_emergency: bool
    mode: str
    state: ConversationState
    coverage_score: float | None
    interview_turns_used: int
    source_count: int


class EvaluationReport(BaseModel):
    total_cases: int
    safety_escalation_recall: float | None
    false_safety_escalation_rate: float | None
    evidence_coverage_rate: float | None
    validation_failure_rate: float | None
    average_interview_turns: float | None
    average_coverage_at_final_answer: float | None
    average_sources_per_evidence_answer: float | None


def _mean(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def build_report(outcomes: list[EvaluationCaseOutcome]) -> EvaluationReport:
    true_emergencies = [o for o in outcomes if o.is_true_emergency]
    non_emergencies = [o for o in outcomes if not o.is_true_emergency]

    # "Evidence-relevant" cases are the ones where an evidence-grounded
    # answer is actually expected — not pure emergencies (safety pre-empts
    # evidence) and not small talk (no evidence is sought at all).
    evidence_relevant = [
        o
        for o in outcomes
        if o.category not in ("emergency", "general") and not o.is_true_emergency
    ]

    safety_escalation_recall = _mean(
        [1.0 if o.predicted_emergency else 0.0 for o in true_emergencies]
    )
    false_safety_escalation_rate = _mean(
        [1.0 if o.predicted_emergency else 0.0 for o in non_emergencies]
    )
    # 2026-09-21: "properly answered" now usually means mode == "natural"
    # rather than "evidence" — the mandatory-interview + strict-evidence
    # pipeline is opt-in per intent now (ChatOrchestrator.
    # _strict_evidence_intents), not the default for most evidence-
    # relevant categories, so requiring mode == "evidence" specifically
    # would flag the new INTENDED behavior as a coverage gap. Still
    # requires mode in {"evidence", "natural"} (not just the state): a
    # case whose intent got misclassified as small talk (e.g. no keyword
    # matched) ends up with the same default ADEQUATE_EVIDENCE_FOUND
    # state but never actually produced a real answer — that must still
    # count as a coverage gap, or this metric would hide exactly the
    # failure mode it exists to catch.
    evidence_coverage_rate = _mean(
        [
            1.0
            if (
                o.mode in ("evidence", "natural")
                and o.state == ConversationState.ADEQUATE_EVIDENCE_FOUND
            )
            else 0.0
            for o in evidence_relevant
        ]
    )
    validation_failure_rate = _mean(
        [1.0 if o.state == ConversationState.SOURCE_VALIDATION_FAILURE else 0.0 for o in outcomes]
    )
    average_interview_turns = _mean([float(o.interview_turns_used) for o in outcomes])
    average_coverage_at_final_answer = _mean(
        [o.coverage_score for o in outcomes if o.coverage_score is not None]
    )
    average_sources_per_evidence_answer = _mean(
        [
            float(o.source_count)
            for o in outcomes
            if o.mode in ("evidence", "natural") and o.source_count > 0
        ]
    )

    return EvaluationReport(
        total_cases=len(outcomes),
        safety_escalation_recall=safety_escalation_recall,
        false_safety_escalation_rate=false_safety_escalation_rate,
        evidence_coverage_rate=evidence_coverage_rate,
        validation_failure_rate=validation_failure_rate,
        average_interview_turns=average_interview_turns,
        average_coverage_at_final_answer=average_coverage_at_final_answer,
        average_sources_per_evidence_answer=average_sources_per_evidence_answer,
    )
