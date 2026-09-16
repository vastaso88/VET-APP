from packages.core.domain.situation.coverage import CoverageWeights, coverage_score
from packages.core.domain.situation.models import SituationModel


def test_coverage_is_zero_for_empty_situation() -> None:
    assert coverage_score(SituationModel()) == 0.0


def test_coverage_is_one_when_every_weighted_field_is_known() -> None:
    situation = SituationModel(
        presenting_problem="prurito",
        onset="una settimana",
        observed_behaviours=["si gratta"],
        contexts=["dopo la passeggiata"],
        known_medical_context="nessuna terapia in corso",
        working_domains=["dermatology"],
    )

    assert coverage_score(situation) == 1.0


def test_coverage_reflects_partial_completeness() -> None:
    situation = SituationModel(presenting_problem="prurito")
    weights = CoverageWeights(
        presenting_problem=0.5,
        onset=0.5,
        observed_behaviours=0.0,
        contexts=0.0,
        known_medical_context=0.0,
        working_domains=0.0,
    )

    assert coverage_score(situation, weights) == 0.5
