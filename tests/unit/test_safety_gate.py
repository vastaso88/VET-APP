from packages.core.application.services.safety_gate import SafetyGate


def test_safety_gate_flags_red_flag_keywords() -> None:
    gate = SafetyGate()

    flags = gate.evaluate("Il cane ha avuto un collasso improvviso")

    assert flags


def test_safety_gate_is_case_insensitive() -> None:
    gate = SafetyGate()

    flags = gate.evaluate("IL GATTO NON RESPIRA BENE")

    assert flags


def test_safety_gate_returns_empty_list_for_ordinary_messages() -> None:
    gate = SafetyGate()

    flags = gate.evaluate("Il mio cane mangia poco da stamattina")

    assert flags == []


def test_safety_gate_flags_blood_in_vomit_or_stool() -> None:
    # Real-world finding: an owner reporting "vomito con sangue" (blood in
    # vomit) is a genuine red flag that the previous keyword list ("emorrag",
    # "sanguina") didn't catch at all.
    gate = SafetyGate()

    assert gate.evaluate("Ha avuto un episodio di vomito con sangue ieri sera")
    assert gate.evaluate("Ho notato sangue nelle feci stamattina")


def test_safety_gate_does_not_flag_routine_bloodwork_mentions() -> None:
    # The bare word "sangue" is deliberately NOT a keyword on its own: it
    # would also match calm, already-reassuring statements about normal
    # bloodwork, wrongly escalating them into urgent triage.
    gate = SafetyGate()

    flags = gate.evaluate(
        "Abbiamo fatto le analisi del sangue e sono tutte nella norma, nessun problema"
    )

    assert flags == []
