from ai_core.knowledge.quality.confidence_model import EvidencePack
from ai_core.knowledge.quality.quality_firewall import QualityFirewall
from packages.core.domain.knowledge.models import EvidenceSource


def test_weak_evidence_is_blocked() -> None:
    firewall = QualityFirewall()
    pack = EvidencePack(
        pet_species="cat",
        clinical_domain="clinical",
        owner_question="Il mio gatto tossisce, cosa significa?",
        sources=[
            EvidenceSource(
                title="Old generic pet blog",
                year=2009,
                tier="D",
                species="other",
                clinical_domain="clinical",
                snippet="Cough can happen.",
                trust_score=0.2,
            )
        ],
    )

    decision = firewall.evaluate_evidence(pack)

    assert decision.rejected
    assert decision.trigger_unknown_mode


def test_species_mismatch_is_detected() -> None:
    firewall = QualityFirewall()
    pack = EvidencePack(
        pet_species="rabbit",
        clinical_domain="nutrition",
        owner_question="Il mio coniglio mangia poco",
        sources=[
            EvidenceSource(
                title="Feline nutrition review",
                year=2024,
                tier="A",
                species="cat",
                clinical_domain="nutrition",
                snippet="Hydration monitoring remains central in feline reduced appetite.",
                trust_score=0.9,
            )
        ],
    )

    decision = firewall.evaluate_evidence(pack)

    assert decision.rejected
    assert "species_mismatch" in decision.reasons


def test_contradiction_is_detected() -> None:
    firewall = QualityFirewall()
    pack = EvidencePack(
        pet_species="dog",
        clinical_domain="clinical",
        owner_question="Il mio cane tossisce",
        sources=[
            EvidenceSource(
                title="Emergency guidance",
                year=2024,
                tier="A",
                species="dog",
                clinical_domain="clinical",
                snippet="Immediate emergency evaluation is required when cough progresses with effort.",
                trust_score=0.95,
            ),
            EvidenceSource(
                title="Monitoring note",
                year=2024,
                tier="A",
                species="dog",
                clinical_domain="clinical",
                snippet="Monitor at home if cough is isolated and the pet remains bright.",
                trust_score=0.9,
            ),
        ],
    )

    decision = firewall.evaluate_evidence(pack)

    assert decision.contradiction_assessment.contradiction_flag
    assert decision.trigger_unknown_mode
