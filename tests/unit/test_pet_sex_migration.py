"""Sex and neutering became separate fields (2026-10-14): the data migration
(run for real on SQLite, whose UPDATE/CASE semantics match Postgres here), the
read-side normalisation of old values, and the microchip / detail validation."""

import re
import sqlite3
from pathlib import Path

import pytest
from pydantic import ValidationError

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.update_pet_profile import (
    UpdatePetProfileInput,
    UpdatePetProfileService,
)
from packages.core.domain.pet_profile.details import (
    describe_for_prompt,
    is_valid_microchip,
    normalize_microchip,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.pet_profile.sex import LEGACY_SEX_VALUES, split_legacy_sex
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import InMemoryPetProfileRepository
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


class RecordingLLMClient:
    def __init__(self) -> None:
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content="Risposta in prosa senza citazioni.",
            provider="fake",
            model="fake-model",
            token_count=5,
        )


SCHEMA = Path(__file__).resolve().parents[2] / "scripts" / "setup" / "supabase_schema.sql"


def _migration_sql() -> str:
    text = SCHEMA.read_text(encoding="utf-8")
    match = re.search(r"-- migrate-sex:begin\n(.*?)-- migrate-sex:end", text, re.DOTALL)
    assert match, "migrate-sex block missing from supabase_schema.sql"
    return match.group(1).replace("public.", "")


def _database() -> sqlite3.Connection:
    connection = sqlite3.connect(":memory:")
    connection.execute("create table pet_profiles (id text, sex text, is_sterilized boolean)")
    return connection


def test_migration_splits_every_legacy_value_in_the_database() -> None:
    connection = _database()
    legacy = [*LEGACY_SEX_VALUES, "Maschio", "Femmina", "Sconosciuto", None]
    connection.executemany(
        "insert into pet_profiles (id, sex) values (?, ?)",
        [(f"pet-{index}", sex) for index, sex in enumerate(legacy)],
    )

    connection.executescript(_migration_sql())

    by_original = {
        original: connection.execute(
            "select sex, is_sterilized from pet_profiles where id = ?", (f"pet-{index}",)
        ).fetchone()
        for index, original in enumerate(legacy)
    }
    for old, (sex, neutered) in LEGACY_SEX_VALUES.items():
        assert by_original[old] == (sex, int(neutered)), old
    # Rows that were already in the new shape are left alone.
    assert by_original["Maschio"] == ("Maschio", None)
    assert by_original["Femmina"] == ("Femmina", None)
    assert by_original["Sconosciuto"] == ("Sconosciuto", None)
    assert by_original[None] == (None, None)


def test_migration_is_idempotent() -> None:
    connection = _database()
    connection.execute(
        "insert into pet_profiles (id, sex) values ('a', 'Femmina sterilizzata'), "
        "('b', 'Maschio intero')"
    )
    connection.executescript(_migration_sql())
    first = connection.execute(
        "select id, sex, is_sterilized from pet_profiles order by id"
    ).fetchall()

    connection.executescript(_migration_sql())

    second = connection.execute(
        "select id, sex, is_sterilized from pet_profiles order by id"
    ).fetchall()
    assert first == second == [("a", "Femmina", 1), ("b", "Maschio", 0)]


def test_migration_does_not_override_a_flag_on_current_values() -> None:
    connection = _database()
    connection.execute("insert into pet_profiles values ('a', 'Femmina', 1)")

    connection.executescript(_migration_sql())

    assert connection.execute("select sex, is_sterilized from pet_profiles").fetchone() == (
        "Femmina",
        1,
    )


@pytest.mark.parametrize(
    ("stored", "expected"),
    [
        ("Femmina sterilizzata", ("Femmina", True)),
        ("Maschio castrato", ("Maschio", True)),
        ("Maschio intero", ("Maschio", False)),
        ("Femmina intera", ("Femmina", False)),
        ("Maschio", ("Maschio", None)),
        ("Sconosciuto", ("Sconosciuto", None)),
        (None, (None, None)),
    ],
)
def test_split_legacy_sex(stored: str | None, expected: tuple[str | None, bool | None]) -> None:
    assert split_legacy_sex(stored) == expected


def test_a_profile_read_with_an_old_sex_value_comes_out_split() -> None:
    pet = PetProfile.model_validate(
        {
            "id": "p",
            "owner_id": "o",
            "name": "Luna",
            "species": "Gatto",
            "sex": "Femmina sterilizzata",
        }
    )

    assert pet.sex == "Femmina"
    assert pet.is_sterilized is True


def test_an_explicit_neutering_flag_wins_over_the_old_value() -> None:
    pet = PetProfile(
        owner_id="o", name="Luna", species="Gatto", sex="Femmina intera", is_sterilized=True
    )

    assert (pet.sex, pet.is_sterilized) == ("Femmina", True)


def test_updating_a_pet_normalises_and_validates_the_new_fields() -> None:
    repository = InMemoryPetProfileRepository()
    repository.save(PetProfile(id="p", owner_id="o", name="Luna", species="Cane"))
    service = UpdatePetProfileService(repository)

    updated = service.execute(
        UpdatePetProfileInput(
            pet_id="p",
            name="Luna",
            species="Cane",
            sex="Maschio castrato",
            microchip_number="380 260 000 123 456",
            body_condition="thin",
            activity_level="active",
        )
    ).pet_profile

    assert (updated.sex, updated.is_sterilized) == ("Maschio", True)
    assert updated.microchip_number == "380260000123456"
    assert repository.get("p") == updated


@pytest.mark.parametrize("value", ["12345", "38026000012345a", "3802600001234567", "abc"])
def test_a_malformed_microchip_is_rejected(value: str) -> None:
    with pytest.raises(ValidationError):
        PetProfile(owner_id="o", name="Luna", species="Cane", microchip_number=value)


def test_microchip_is_optional_and_tolerates_spaces() -> None:
    assert is_valid_microchip(None)
    assert is_valid_microchip("")
    assert is_valid_microchip("   ")
    assert is_valid_microchip("380 2600 0012 3456")
    assert is_valid_microchip("380-260-000-123-456")
    assert not is_valid_microchip("38026000012345")
    assert normalize_microchip("") is None
    assert (
        PetProfile(owner_id="o", name="L", species="Cane", microchip_number="").microchip_number
        is None
    )


def test_unknown_body_condition_or_activity_level_is_rejected() -> None:
    with pytest.raises(ValidationError):
        PetProfile(owner_id="o", name="L", species="Cane", body_condition="chubby")
    with pytest.raises(ValidationError):
        PetProfile(owner_id="o", name="L", species="Cane", activity_level="hyper")


def test_prompt_lines_cover_only_what_was_filled_in() -> None:
    assert describe_for_prompt(neutered=None, body_condition=None, activity_level=None) == []
    assert describe_for_prompt(
        neutered=True, body_condition="slightly_overweight", activity_level="sedentary"
    ) == [
        "Neutered/spayed: yes",
        "Body condition (owner's estimate): slightly overweight",
        "Activity level: sedentary",
    ]
    assert describe_for_prompt(neutered=False, body_condition="x", activity_level=None) == [
        "Neutered/spayed: no"
    ]


def test_chat_context_carries_neutering_condition_and_activity_but_not_the_microchip() -> None:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Milo si gratta spesso l'orecchio da ieri",
            species="Cane",
            pet_name="Milo",
            is_sterilized=True,
            body_condition="overweight",
            activity_level="sedentary",
        )
    )

    prompt = client.requests[-1].user_prompt
    assert "Neutered/spayed: yes" in prompt
    assert "Body condition (owner's estimate): overweight" in prompt
    assert "Activity level: sedentary" in prompt
    assert "icrochip" not in prompt


def test_chat_context_omits_details_the_owner_never_filled_in() -> None:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())

    orchestrator.answer(
        ChatOrchestratorInput(
            user_message="Milo si gratta spesso l'orecchio da ieri", species="Cane", pet_name="Milo"
        )
    )

    prompt = client.requests[-1].user_prompt
    for label in ("Neutered", "Body condition", "Activity level"):
        assert label not in prompt
