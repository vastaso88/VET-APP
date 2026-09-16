from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.evaluation.metrics import (
    EvaluationCaseOutcome,
    EvaluationReport,
    build_report,
)
from packages.core.domain.evaluation.scenarios import EvaluationScenario


class EvaluationRunner:
    """Runs the labeled scenario set through a real ChatOrchestrator and
    reports the Beta metrics (spec v3 §41-43) — the team's regression net
    for the safety gate, evidence retrieval, and citation verification.

    Deliberately single-turn per scenario (interview loop's own effect on
    the metrics — question quality, turns-to-coverage — needs a separate
    scripted multi-turn harness; this one isolates the safety/evidence/
    validation layers that spec v3 §42 actually measures).
    """

    def __init__(self, orchestrator: ChatOrchestrator) -> None:
        self._orchestrator = orchestrator

    def run(self, scenarios: list[EvaluationScenario]) -> EvaluationReport:
        return build_report([self._run_one(scenario) for scenario in scenarios])

    def _run_one(self, scenario: EvaluationScenario) -> EvaluationCaseOutcome:
        result = self._orchestrator.answer(
            ChatOrchestratorInput(
                user_message=scenario.message,
                species=scenario.species,
                pet_name=scenario.pet_name,
            )
        )
        return EvaluationCaseOutcome(
            scenario_id=scenario.id,
            category=scenario.category,
            is_true_emergency=scenario.is_true_emergency,
            predicted_emergency=result.mode == "triage",
            mode=result.mode,
            state=result.state,
            coverage_score=result.coverage_score,
            interview_turns_used=result.interview_turns_used,
            source_count=len(result.sources),
        )
