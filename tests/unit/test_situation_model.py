from packages.core.domain.situation.models import SituationModel


def test_merge_overwrites_scalars_only_when_update_has_a_value() -> None:
    current = SituationModel(presenting_problem="tosse", onset="2 giorni")
    update = SituationModel(presenting_problem="tosse persistente")

    merged = current.merge(update)

    assert merged.presenting_problem == "tosse persistente"
    assert merged.onset == "2 giorni"


def test_merge_unions_list_fields_without_duplicates() -> None:
    current = SituationModel(observed_behaviours=["abbaia"])
    update = SituationModel(observed_behaviours=["abbaia", "trema"])

    merged = current.merge(update)

    assert merged.observed_behaviours == ["abbaia", "trema"]


def test_merge_with_empty_update_keeps_current_values() -> None:
    current = SituationModel(presenting_problem="vomito", contexts=["dopo i pasti"])

    merged = current.merge(SituationModel())

    assert merged.presenting_problem == "vomito"
    assert merged.contexts == ["dopo i pasti"]
