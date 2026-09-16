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


def test_evidence_coverage_rate_reflects_the_known_keyword_classifier_gap() -> None:
    # "ambiguous-tired" ("un po' più stanco del solito") matches none of
    # EVIDENCE_KEYWORDS, so it's routed to general_info and never attempts
    # retrieval at all — this is a real, known gap in the crude keyword
    # intent classifier, not a bug in the metric. If this test's number
    # goes DOWN further, something new broke; if it goes UP, the intent
    # classifier probably improved and this scenario/assertion should be
    # revisited.
    report = _runner().run(DEFAULT_SCENARIOS)

    assert report.evidence_coverage_rate == 5 / 6


def test_validation_failure_rate_is_zero_for_the_well_behaved_echo_provider() -> None:
    report = _runner().run(DEFAULT_SCENARIOS)

    assert report.validation_failure_rate == 0.0
