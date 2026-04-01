from ai_core.education.education_engine import EducationEngine
from ai_core.education.education_formatter import EducationFormatter
from ai_core.education.owner_profiles import OwnerKnowledgeProfile
from packages.core.domain.knowledge.models import EvidenceSource


def test_education_output_is_readable() -> None:
    engine = EducationEngine()
    formatter = EducationFormatter()
    profile = OwnerKnowledgeProfile(experience_level="new_owner", communication_style="simple")
    payload = engine.build_education_blocks(
        [
            EvidenceSource(
                title="Nutritional Assessment Guidelines",
                year=2023,
                tier="A",
                species="cat",
                clinical_domain="nutrition",
                snippet="Reduced appetite should be evaluated together with hydration and energy level.",
                trust_score=0.9,
            )
        ],
        profile,
    )

    rendered = formatter.format_payload(payload, profile)

    assert "Monitoraggio:" in rendered
    assert "Queste indicazioni sono educative" in rendered
    assert len(rendered) > 80
