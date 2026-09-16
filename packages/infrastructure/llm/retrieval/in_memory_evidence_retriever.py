from packages.core.application.ports.evidence_retriever import (
    EvidenceRetrievalRequest,
    EvidenceRetriever,
)
from packages.core.domain.knowledge.models import EvidenceSource

CATALOG = [
    EvidenceSource(
        title="AAHA Canine Life Stage Guidelines",
        journal="Journal of the American Animal Hospital Association",
        year=2023,
        tier="A",
        clinical_domain="preventive",
        species="dog",
        snippet=(
            "Preventive care plans should be adapted to age, lifestyle, vaccination "
            "status, and risk exposure."
        ),
    ),
    EvidenceSource(
        title="2024 Feline Chronic Kidney Disease Review",
        journal="Journal of Feline Medicine and Surgery",
        year=2024,
        tier="A",
        clinical_domain="nutrition",
        species="cat",
        snippet=(
            "Nutritional support and hydration monitoring remain central in feline "
            "CKD management."
        ),
    ),
    EvidenceSource(
        title="Small Animal Coughing: Diagnostic Approach Review",
        journal="Veterinary Clinics of North America: Small Animal Practice",
        year=2022,
        tier="B",
        clinical_domain="clinical",
        species="dog",
        snippet=(
            "Persistent coughing requires assessment of duration, respiratory "
            "effort, and associated systemic signs."
        ),
    ),
    EvidenceSource(
        title="Nutritional Assessment Guidelines for Dogs and Cats",
        journal="WSAVA Global Nutrition Committee",
        year=2021,
        tier="A",
        clinical_domain="nutrition",
        species="other",
        snippet=(
            "Reduced appetite should be evaluated together with hydration, body "
            "condition, and concurrent disease."
        ),
    ),
    EvidenceSource(
        title="Behavior Problems in Companion Animals",
        journal="Veterinary Clinics of North America: Small Animal Practice",
        year=2020,
        tier="B",
        clinical_domain="behavior",
        species="other",
        snippet=(
            "Behavior complaints should be assessed with environment, triggers, "
            "and reinforcement history."
        ),
    ),
]

QUERY_HINTS: dict[str, tuple[str, ...]] = {
    "clinical_question": ("tosse", "tossisce", "cough", "vomita", "vomit", "diarrea"),
    "nutrition_question": ("mangia", "aliment", "dieta", "nutrition"),
    "behavior_question": ("ansia", "abbaia", "graffia", "aggress", "comport"),
    "preventive_care": ("vaccin", "preven", "checkup", "profilassi"),
}


class InMemoryEvidenceRetriever(EvidenceRetriever):
    def retrieve(self, request: EvidenceRetrievalRequest) -> list[EvidenceSource]:
        domain = self._domain_from_request(request)
        results = [
            source
            for source in CATALOG
            if (source.species == request.species or source.species == "other")
            and source.clinical_domain == domain
        ]
        return results[: request.max_results]

    @staticmethod
    def _domain_from_request(request: EvidenceRetrievalRequest) -> str:
        query = request.query.lower()
        for intent, hints in QUERY_HINTS.items():
            if request.intent == intent or any(hint in query for hint in hints):
                return {
                    "clinical_question": "clinical",
                    "nutrition_question": "nutrition",
                    "behavior_question": "behavior",
                    "preventive_care": "preventive",
                }[intent]
        return "general"
