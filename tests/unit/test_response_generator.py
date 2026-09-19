from packages.core.application.services.response_generator import ResponseGenerator
from packages.core.domain.knowledge.evidence_synthesis import EvidenceSynthesis


def test_renders_only_supported_claims_as_a_short_direct_answer() -> None:
    generator = ResponseGenerator()
    synthesis = EvidenceSynthesis(supported_claims=["Il riposo aiuta il recupero [1]."])

    text = generator.render(synthesis)

    assert text == "Il riposo aiuta il recupero [1]."


def test_renders_uncertain_claims_with_a_hedge() -> None:
    generator = ResponseGenerator()
    synthesis = EvidenceSynthesis(uncertain_claims=["il digiuno di un giorno possa aiutare"])

    text = generator.render(synthesis)

    assert "non è del tutto certo" in text
    assert "il digiuno di un giorno possa aiutare" in text


def test_renders_conflicting_evidence_explicitly() -> None:
    generator = ResponseGenerator()
    synthesis = EvidenceSynthesis(conflicting_evidence=["l'effetto della dieta X sul peso"])

    text = generator.render(synthesis)

    assert "non sono concordi" in text


def test_renders_safe_actions_monitoring_and_referral_sections() -> None:
    generator = ResponseGenerator()
    synthesis = EvidenceSynthesis(
        supported_claims=["Claim di base [1]."],
        safe_owner_actions=["offri acqua fresca"],
        monitoring_points=["il livello di energia"],
        referral_conditions=["i sintomi peggiorano"],
    )

    text = generator.render(synthesis)

    assert "Nel frattempo puoi: offri acqua fresca." in text
    assert "Tieni d'occhio: il livello di energia." in text
    assert "Contatta il veterinario se: i sintomi peggiorano." in text


def test_renders_empty_string_for_an_empty_synthesis() -> None:
    generator = ResponseGenerator()

    text = generator.render(EvidenceSynthesis())

    assert text == ""
