from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.domain.medical_record.models import ClinicalEvent


class MedicalRecordContextRetriever:
    """Selective, summarized access to a pet's clinical documents (spec v3
    §18): the orchestrator only calls this AFTER the owner has consented,
    and it returns a short summary — never the full record — to keep the
    LLM prompt minimal (spec v3 §38, data minimization).
    """

    def __init__(self, repository: ClinicalEventRepository, *, max_entries: int = 3) -> None:
        self._repository = repository
        self._max_entries = max_entries

    def summarize_for_pet(self, pet_id: str) -> str | None:
        events = self._repository.list_by_pet(pet_id)
        if not events:
            return None
        recent = sorted(
            events, key=lambda event: event.created_at, reverse=True
        )[: self._max_entries]
        lines = [self._format_event(event) for event in recent]
        return "\n".join(lines)

    @staticmethod
    def _format_event(event: ClinicalEvent) -> str:
        detail = f": {event.subtitle}" if event.subtitle else ""
        return f"- {event.title}{detail}"
