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
