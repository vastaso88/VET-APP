"""Run the labeled evaluation scenarios and print the Beta metrics report
(spec v3 §41-43).

Uses whatever LLM_PROVIDER / EVIDENCE_BACKEND is configured via the normal
settings (.env or environment variables) — defaults to echo + in_memory,
so `python scripts/eval/run_evaluation.py` costs nothing and needs no
network access. Point it at a real provider/backend to evaluate those:

    LLM_PROVIDER=groq EVIDENCE_BACKEND=europe_pmc python scripts/eval/run_evaluation.py
"""

from __future__ import annotations

from packages.bootstrap.container import get_container
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.evaluation_runner import EvaluationRunner
from packages.core.domain.evaluation.metrics import EvaluationReport
from packages.core.domain.evaluation.scenarios import DEFAULT_SCENARIOS


def _format_rate(value: float | None) -> str:
    return "n/d" if value is None else f"{value * 100:.0f}%"


def _format_number(value: float | None) -> str:
    return "n/d" if value is None else f"{value:.2f}"


def print_report(report: EvaluationReport) -> None:
    print(f"Casi valutati: {report.total_cases}")
    print(f"Safety Escalation Recall:        {_format_rate(report.safety_escalation_recall)}")
    print(f"False Safety Escalation Rate:    {_format_rate(report.false_safety_escalation_rate)}")
    print(f"Evidence Coverage Rate:          {_format_rate(report.evidence_coverage_rate)}")
    print(f"Validation Failure Rate:         {_format_rate(report.validation_failure_rate)}")
    print(f"Interview turns medi:            {_format_number(report.average_interview_turns)}")
    print(
        "Coverage media a risposta finale:",
        _format_number(report.average_coverage_at_final_answer),
    )
    print(
        "Fonti medie per risposta:        ",
        _format_number(report.average_sources_per_evidence_answer),
    )


def main() -> None:
    container = get_container()
    # Deliberately NOT container.chat_orchestrator: this suite isolates the
    # safety/evidence/citation layers (spec v3 §42), independent of whether
    # the interview loop happens to be on in the running deployment's
    # settings — reuses the same LLM client, evidence retriever and PII
    # anonymizer the container built, just without the multi-turn wrapper.
    orchestrator = ChatOrchestrator(
        container.llm_client,
        container.evidence_retriever,
        container.pii_anonymizer,
        enable_interview_loop=False,
    )
    report = EvaluationRunner(orchestrator).run(DEFAULT_SCENARIOS)
    print_report(report)


if __name__ == "__main__":
    main()
