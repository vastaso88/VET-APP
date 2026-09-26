from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.evaluation_runner import EvaluationRunner
from packages.core.domain.evaluation.scenarios import DEFAULT_SCENARIOS
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.shared.config.settings import Settings


def _runner() -> EvaluationRunner:
    orchestrator = ChatOrchestrator(
        EchoLLMClient(Settings()), InMemoryEvidenceRetriever(), NoopPiiAnonymizer()
    )
    return EvaluationRunner(orchestrator)


def test_runs_every_scenario_exactly_once() -> None:
    report = _runner().run(DEFAULT_SCENARIOS)

    assert report.total_cases == len(DEFAULT_SCENARIOS)


def test_safety_gate_catches_all_labeled_emergencies_in_the_default_set() -> None:
    # A regression net: if this ever drops below 1.0, either a scenario's
    # wording drifted or the SafetyGate's keyword list lost coverage.
    report = _runner().run(DEFAULT_SCENARIOS)

    assert report.safety_escalation_recall == 1.0


def test_safety_gate_does_not_escalate_the_labeled_non_emergencies() -> None:
    report = _runner().run(DEFAULT_SCENARIOS)

    assert report.false_safety_escalation_rate == 0.0


def test_evidence_coverage_rate_is_perfect_now_that_natural_answers_dont_require_sources() -> None:
    # "ambiguous-tired" ("un po' più stanco del solito") is vague enough
    # that InMemoryEvidenceRetriever finds zero sources for it. Under the
    # old strict evidence-gate this used to be an uncovered gap (mode
    # "evidence" but state INSUFFICIENT_EVIDENCE, since no sources meant
    # a hard refusal). Under the 2026-09-21 architecture, clinical
    # questions default to `_generate_natural_answer`, which answers
    # regardless of whether retrieval found anything — so this scenario
    # now counts as covered. If this drops below 1.0, something (likely
    # a genuine safety/validation failure) regressed.
    report = _runner().run(DEFAULT_SCENARIOS)

    assert report.evidence_coverage_rate == 1.0


def test_validation_failure_rate_is_zero_for_the_well_behaved_echo_provider() -> None:
    report = _runner().run(DEFAULT_SCENARIOS)

    assert report.validation_failure_rate == 0.0
