from datetime import UTC, date, datetime, timedelta

from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.domain.medical_record.models import (
    CONDITION_RESOLVED,
    ClinicalEvent,
    PetCondition,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryClinicalEventRepository,
    InMemoryPetConditionRepository,
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


def test_each_entry_says_its_category_and_the_date_of_the_event() -> None:
    repo = InMemoryClinicalEventRepository(
        seed=[
            ClinicalEvent(
                pet_id="pet-1",
                title="Controllo annuale",
                category="visit",
                subtype="checkup",
                event_date=date(2026, 5, 2),
            ),
            ClinicalEvent(pet_id="pet-1", title="Richiamo", category="vaccine"),
            ClinicalEvent(pet_id="pet-1", title="Scansione", category="document"),
        ]
    )

    summary = MedicalRecordContextRetriever(repo).summarize_for_pet("pet-1")

    assert summary is not None
    lines = summary.splitlines()
    assert "- Controllo annuale (visita: visita di controllo, 02/05/2026)" in lines
    assert "- Richiamo (vaccino)" in lines
    assert "- Scansione (documento)" in lines


def test_the_owners_notes_never_reach_the_chat() -> None:
    repo = InMemoryClinicalEventRepository(
        seed=[ClinicalEvent(pet_id="pet-1", title="Visita", category="visit", notes="segreto")]
    )

    summary = MedicalRecordContextRetriever(repo).summarize_for_pet("pet-1")

    assert summary is not None
    assert "segreto" not in summary


def test_only_ongoing_conditions_are_read_with_name_and_start_date() -> None:
    conditions = InMemoryPetConditionRepository(
        seed=[
            PetCondition(
                pet_id="pet-1",
                name="Otite",
                started_on=date(2026, 2, 1),
                therapy="gocce",
                notes="orecchio sinistro",
            ),
            PetCondition(
                pet_id="pet-1",
                name="Gastrite",
                started_on=date(2025, 1, 1),
                status=CONDITION_RESOLVED,
                ended_on=date(2025, 2, 1),
            ),
            PetCondition(pet_id="pet-2", name="Dermatite"),
        ]
    )
    retriever = MedicalRecordContextRetriever(
        InMemoryClinicalEventRepository(), condition_repository=conditions
    )

    summary = retriever.summarize_for_pet("pet-1")

    assert summary == "Malattie in corso:\n- Otite (dal 01/02/2026)"


def test_a_pet_with_only_conditions_still_has_a_summary() -> None:
    conditions = InMemoryPetConditionRepository(seed=[PetCondition(pet_id="pet-1", name="Otite")])
    retriever = MedicalRecordContextRetriever(
        InMemoryClinicalEventRepository(), condition_repository=conditions
    )

    assert retriever.summarize_for_pet("pet-1") == "Malattie in corso:\n- Otite"
    assert retriever.summarize_for_pet("pet-2") is None


def test_conditions_that_cannot_be_read_do_not_break_the_entries() -> None:
    class Broken:
        def list_by_pet(self, pet_id: str) -> list[PetCondition]:
            raise RuntimeError('relation "pet_conditions" does not exist')

    repo = InMemoryClinicalEventRepository(seed=[_event("pet-1", "Referto", days_ago=1)])
    retriever = MedicalRecordContextRetriever(repo, condition_repository=Broken())

    assert retriever.summarize_for_pet("pet-1") == "- Referto"
