from datetime import UTC, datetime, timedelta

from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryClinicalEventRepository,
)


def _event(pet_id: str, title: str, *, days_ago: int, subtitle: str | None = None) -> ClinicalEvent:
    return ClinicalEvent(
        pet_id=pet_id,
        title=title,
        subtitle=subtitle,
        created_at=datetime.now(UTC) - timedelta(days=days_ago),
    )


def test_returns_none_when_pet_has_no_records() -> None:
    retriever = MedicalRecordContextRetriever(InMemoryClinicalEventRepository())

    assert retriever.summarize_for_pet("pet-1") is None


def test_summarizes_most_recent_records_first() -> None:
    repo = InMemoryClinicalEventRepository(
        seed=[
            _event("pet-1", "Esame ematico", days_ago=10, subtitle="controlli di routine"),
            _event("pet-1", "Richiamo vaccinale", days_ago=1),
        ]
    )
    retriever = MedicalRecordContextRetriever(repo)

    summary = retriever.summarize_for_pet("pet-1")

    assert summary is not None
    lines = summary.splitlines()
    assert lines[0] == "- Richiamo vaccinale"
    assert lines[1] == "- Esame ematico: controlli di routine"


def test_only_includes_records_for_the_requested_pet() -> None:
    repo = InMemoryClinicalEventRepository(
        seed=[
            _event("pet-1", "Referto di pet 1", days_ago=1),
            _event("pet-2", "Referto di pet 2", days_ago=1),
        ]
    )
    retriever = MedicalRecordContextRetriever(repo)

    summary = retriever.summarize_for_pet("pet-2")

    assert summary == "- Referto di pet 2"


def test_caps_the_number_of_entries() -> None:
    repo = InMemoryClinicalEventRepository(
        seed=[_event("pet-1", f"Evento {i}", days_ago=i) for i in range(5)]
    )
    retriever = MedicalRecordContextRetriever(repo, max_entries=2)

    summary = retriever.summarize_for_pet("pet-1")

    assert summary is not None
    assert len(summary.splitlines()) == 2
