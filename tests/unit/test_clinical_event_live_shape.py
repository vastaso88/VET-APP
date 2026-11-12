from typing import Any

from test_chat_orchestrator import FakeLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryClinicalEventRepository,
)
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseClinicalEventRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

# The live `clinical_events` table as read on 2026-10-04: it predates this
# project's schema script, so it has its own columns and lacks the app's.
LIVE_ROW: dict[str, Any] = {
    "id": "evt-1",
    "owner_id": "owner-1",
    "pet_id": "pet-1",
    "event_type": "document",
    "title": "Esami del sangue",
    "event_date": "2026-09-12",
    "summary": "Creatinina lievemente alta",
    "severity": None,
    "source": None,
    "linked_document_id": None,
    "created_at": "2026-10-01T09:30:00.123456+00:00",
    "attachment_id": None,
}

# The same row once the five app columns have been added.
LIVE_ROW_AFTER_MIGRATION: dict[str, Any] = {
    **LIVE_ROW,
    "pet_name": "Thor",
    "subtitle": "Controllo annuale",
    "meta": "12 set 2026",
    "badge": "Referto",
    "detail_source": "Caricato dal proprietario",
}


class _Response:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self._rows = rows

    def select(self, _columns: str) -> "_Query":
        return self

    def eq(self, column: str, value: str) -> "_Query":
        return _Query([row for row in self._rows if row.get(column) == value])

    def execute(self) -> _Response:
        return _Response(self._rows)


class _Client:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self._rows = rows

    def table(self, _name: str) -> _Query:
        return _Query(self._rows)


def _repository(row: dict[str, Any]) -> SupabaseClinicalEventRepository:
    client: Any = _Client([row])
    return SupabaseClinicalEventRepository(client)


def test_a_live_row_is_read_before_the_migration() -> None:
    repository = _repository(LIVE_ROW)

    [event] = repository.list_by_pet("pet-1")

    assert event.title == "Esami del sangue"
    assert event.summary == "Creatinina lievemente alta"
    assert event.event_date is not None and event.event_date.isoformat() == "2026-09-12"
    assert event.subtitle is None


def test_a_live_row_is_read_after_the_migration() -> None:
    repository = _repository(LIVE_ROW_AFTER_MIGRATION)

    [event] = repository.list_by_pet("pet-1")

    assert event.subtitle == "Controllo annuale"
    assert event.badge == "Referto"


def test_null_optional_columns_do_not_break_the_whole_record() -> None:
    row = {**LIVE_ROW, "title": None, "created_at": None, "summary": None, "event_date": None}

    event = ClinicalEvent.model_validate(row)

    assert event.title == ""
    assert event.created_at.tzinfo is not None


def test_text_and_timestamptz_creation_times_sort_together() -> None:
    # Our schema script declared created_at as text; the live column is
    # timestamptz. A naive and an aware datetime must still compare.
    older = ClinicalEvent.model_validate({**LIVE_ROW, "id": "a", "event_date": None})
    newer = ClinicalEvent.model_validate(
        {**LIVE_ROW, "id": "b", "event_date": None, "created_at": "2026-10-03 08:00:00"}
    )

    assert newer.created_at > older.created_at


def test_the_chat_context_uses_the_live_columns_recent_event_first() -> None:
    old_but_uploaded_last = ClinicalEvent.model_validate(
        {
            **LIVE_ROW,
            "id": "old",
            "title": "Esame vecchio",
            "event_date": "2024-01-10",
            "created_at": "2026-10-03T10:00:00+00:00",
        }
    )
    recent = ClinicalEvent.model_validate(LIVE_ROW)
    retriever = MedicalRecordContextRetriever(
        InMemoryClinicalEventRepository(seed=[old_but_uploaded_last, recent])
    )

    summary = retriever.summarize_for_pet("pet-1")

    assert summary is not None
    first, second = summary.splitlines()
    assert first == "- Esami del sangue (12/09/2026): Creatinina lievemente alta"
    assert second.startswith("- Esame vecchio (10/01/2024)")


def test_the_new_sex_values_reach_the_chat_context_as_written() -> None:
    for sex in (
        "Maschio",
        "Femmina",
        "Maschio intero",
        "Maschio castrato",
        "Femmina intera",
        "Femmina sterilizzata",
    ):
        client = FakeLLMClient()
        orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

        orchestrator.answer(
            ChatOrchestratorInput(
                user_message="Quanto dovrebbe mangiare al giorno?",
                species="dog",
                pet_name="Thor",
                sex=sex,
            )
        )

        assert f"Sex: {sex}" in client.requests[-1].user_prompt, sex
