"""Collaudo K12: a clinical row written with the text column's own default
(`now()::text` = "2026-11-22 10:11:12.123456+00") made the chat of that pet fail with a 500.
The row is read, an unreadable one is skipped without taking the others down, and the log
carries nothing of the row."""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any

import pytest

from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.domain.common.db_timestamps import lenient_timestamp
from packages.core.domain.medical_record.models import ClinicalEvent, PetCondition
from packages.infrastructure.persistence.supabase.supabase_repositories import (
    SupabaseClinicalEventRepository,
    SupabasePetConditionRepository,
)

POSTGRES_TEXT = "2026-11-22 10:11:12.123456+00"
EXPECTED = datetime(2026, 11, 22, 10, 11, 12, 123456, tzinfo=UTC)


@pytest.mark.parametrize(
    "written",
    [
        POSTGRES_TEXT,  # the default of the text column
        "2026-11-22 10:11:12.123456+00:00",
        "2026-11-22T10:11:12.123456+00:00",
        "2026-11-22T10:11:12.123456Z",
        "2026-11-22 10:11:12.123456 +0000",
        "2026-11-22 10:11:12,123456+00",
    ],
)
def test_every_shape_postgres_and_the_app_write_is_read(written: str) -> None:
    event = ClinicalEvent.model_validate({"pet_id": "pet-1", "created_at": written})

    assert event.created_at == EXPECTED


def test_an_offset_other_than_utc_is_kept() -> None:
    event = ClinicalEvent.model_validate(
        {"pet_id": "pet-1", "created_at": "2026-11-22 12:11:12+02"}
    )

    assert event.created_at == datetime(2026, 11, 22, 10, 11, 12, tzinfo=UTC)


def test_a_time_without_an_offset_is_read_as_utc_and_a_date_alone_still_works() -> None:
    assert ClinicalEvent.model_validate(
        {"pet_id": "p", "created_at": "2026-11-22 10:11:12"}
    ).created_at == datetime(2026, 11, 22, 10, 11, 12, tzinfo=UTC)
    assert ClinicalEvent.model_validate({"pet_id": "p", "created_at": "2026-11-22"}).created_at == (
        datetime(2026, 11, 22, tzinfo=UTC)
    )


def test_the_conditions_of_a_pet_read_the_same_text_timestamps() -> None:
    condition = PetCondition.model_validate({"pet_id": "pet-1", "created_at": POSTGRES_TEXT})

    assert condition.created_at == EXPECTED


def test_something_that_is_not_a_date_is_still_refused_by_the_model() -> None:
    with pytest.raises(ValueError):
        ClinicalEvent.model_validate({"pet_id": "pet-1", "created_at": "yesterday evening"})
    assert lenient_timestamp("yesterday evening") == "yesterday evening"
    assert lenient_timestamp(None) is None
    assert lenient_timestamp(5) == 5


class _Response:
    def __init__(self, data: list[dict[str, Any]]) -> None:
        self.data = data


class _Query:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self._rows = rows

    def select(self, _columns: str) -> _Query:
        return self

    def eq(self, column: str, value: str) -> _Query:
        return _Query([row for row in self._rows if row.get(column) == value])

    def execute(self) -> _Response:
        return _Response(self._rows)


class _Client:
    def __init__(self, rows: list[dict[str, Any]]) -> None:
        self._rows = rows

    def table(self, _name: str) -> _Query:
        return _Query(self._rows)


def _row(**changes: Any) -> dict[str, Any]:
    return {
        "id": "evt-1",
        "pet_id": "pet-1",
        "title": "Vaccino",
        "created_at": POSTGRES_TEXT,
        **changes,
    }


def test_a_row_with_the_text_default_no_longer_takes_the_pets_record_down() -> None:
    client: Any = _Client([_row()])
    repository = SupabaseClinicalEventRepository(client)

    [event] = repository.list_by_pet("pet-1")
    summary = MedicalRecordContextRetriever(repository).summarize_for_pet("pet-1")

    assert event.created_at == EXPECTED
    assert summary is not None and "Vaccino" in summary


def test_an_unreadable_row_is_skipped_and_the_others_are_kept(
    caplog: pytest.LogCaptureFixture,
) -> None:
    rows = [
        _row(id="good-1"),
        _row(id="bad", title="Nome privato dell'animale", created_at="yesterday evening"),
        _row(id="good-2", created_at="2026-11-23T08:00:00+00:00"),
    ]
    client: Any = _Client(rows)
    repository = SupabaseClinicalEventRepository(client)

    with caplog.at_level(logging.WARNING):
        events = repository.list_by_pet("pet-1")

    assert [event.id for event in events] == ["good-1", "good-2"]
    logged = " ".join(record.getMessage() for record in caplog.records)
    assert "clinical_events" in logged
    assert "privato" not in logged and "yesterday" not in logged and "pet-1" not in logged
    assert "bad" not in logged


def test_the_same_goes_for_the_conditions_of_a_pet(caplog: pytest.LogCaptureFixture) -> None:
    client: Any = _Client(
        [
            {"id": "c1", "pet_id": "pet-1", "name": "Otite", "created_at": POSTGRES_TEXT},
            {"id": "c2", "pet_id": "pet-1", "name": "x", "created_at": "never"},
        ]
    )

    with caplog.at_level(logging.WARNING):
        conditions = SupabasePetConditionRepository(client).list_by_pet("pet-1")

    assert [c.id for c in conditions] == ["c1"]
    assert "pet_conditions" in " ".join(r.getMessage() for r in caplog.records)
