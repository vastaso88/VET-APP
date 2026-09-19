from pydantic import BaseModel

from packages.core.domain.situation.models import SituationModel


class CoverageWeights(BaseModel):
    """Relative importance of each situation field for the coverage score
    (spec v3 §15: Coverage = Σ(weight_i × completeness_i) / Σ(weight_i)).

    These defaults are a starting point, not a settled product decision —
    see docs/llm master spec §14: the target/weights must stay configurable
    rather than scattered as hardcoded literals through the codebase.
    """

    presenting_problem: float = 0.25
    onset: float = 0.10
    observed_behaviours: float = 0.15
    # Real-world finding: a proper anamnesis (history-taking) always
    # includes a review of systems ("anything else changed — appetite,
    # thirst, energy, toileting?") and a check for recent triggers (diet
    # change, a house move, a new animal, travel) — these two
    # SituationModel fields already existed but were never weighted here
    # nor ever asked about by InterviewPlanner, so they never got
    # populated by the interview at all. Weighted close to
    # observed_behaviours: in real history-taking, "what else changed"
    # routinely surfaces the detail that reframes the whole case.
    associated_signs: float = 0.20
    environmental_changes: float = 0.10
    contexts: float = 0.05
    known_medical_context: float = 0.10
    working_domains: float = 0.05


DEFAULT_COVERAGE_WEIGHTS = CoverageWeights()


def coverage_score(
    situation: SituationModel, weights: CoverageWeights = DEFAULT_COVERAGE_WEIGHTS
) -> float:
    """Situation Coverage Score in [0.00, 1.00] (spec v3 §14).

    This measures how much relevant context has been gathered for the case —
    it is explicitly NOT a diagnostic confidence score.
    """
    completeness = {
        "presenting_problem": bool(situation.presenting_problem),
        "onset": bool(situation.onset),
        "observed_behaviours": bool(situation.observed_behaviours),
        "associated_signs": bool(situation.associated_signs),
        "environmental_changes": bool(situation.environmental_changes),
        "contexts": bool(situation.contexts),
        "known_medical_context": bool(situation.known_medical_context),
        "working_domains": bool(situation.working_domains),
    }
    weight_values: dict[str, float] = weights.model_dump()
    total_weight = sum(weight_values.values())
    if total_weight <= 0:
        return 0.0
    weighted_sum = sum(
        weight_values[field] for field, is_complete in completeness.items() if is_complete
    )
    return min(1.0, weighted_sum / total_weight)
