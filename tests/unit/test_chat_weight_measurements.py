"""The chat reads the pet's latest weighing, with its date, instead of the
free-text weight of the profile (2026-10-14, "Monitoraggio" of the app)."""

from datetime import UTC, date, datetime

import pytest
from llm_fakes import RecordingLLMClient

from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageService,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.pet_profile.weight_measurement import (
    WeightMeasurement,
    format_weight_kg,
    weight_label_with_date,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
    InMemoryWeightMeasurementRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

THIS_YEAR = datetime.now(UTC).year


def _measurement(
    day: date, kg: float, *, pet_id: str = "pet-1", body_condition: int | None = None
) -> WeightMeasurement:
    return WeightMeasurement(
        pet_id=pet_id, measured_at=day, weight_kg=kg, body_condition=body_condition
    )


# --- the text ---------------------------------------------------------------


@pytest.mark.parametrize(
    ("kg", "expected"),
    [
        (23, "23 kg"),
        (23.0, "23 kg"),
        (10.25, "10,25 kg"),
        (4.5, "4,5 kg"),
        (10.206, "10,21 kg"),
        (0.42, "420 g"),
        (0.032, "32 g"),
    ],
)
def test_weight_is_written_the_way_the_app_writes_it(kg: float, expected: str) -> None:
    assert format_weight_kg(kg) == expected


def test_label_carries_the_date_without_the_year_in_the_current_year() -> None:
    label = weight_label_with_date(_measurement(date(2026, 10, 14), 23), today=date(2026, 10, 20))

    assert label == "23 kg al 14 ottobre"


def test_label_carries_the_year_when_it_is_not_the_current_one() -> None:
    label = weight_label_with_date(_measurement(date(2025, 12, 1), 23), today=date(2026, 1, 5))

    assert label == "23 kg al 1 dicembre 2025"


def test_weight_label_never_carries_the_body_condition() -> None:
    """The chat states the corporatura once, in its own line (see below)."""
    label = weight_label_with_date(
        _measurement(date(2026, 10, 14), 23, body_condition=4), today=date(2026, 10, 14)
    )

    assert label == "23 kg al 14 ottobre"


# --- the repository ---------------------------------------------------------


def test_latest_weighing_is_the_most_recent_date_not_the_last_added() -> None:
    repository = InMemoryWeightMeasurementRepository()
    repository.add("owner-1", _measurement(date(2026, 10, 14), 23))
    repository.add("owner-1", _measurement(date(2026, 9, 1), 21))

    latest = repository.latest_for_pet("owner-1", "pet-1")

    assert latest is not None
    assert latest.weight_kg == 23


def test_two_weighings_on_one_day_the_last_added_wins() -> None:
    repository = InMemoryWeightMeasurementRepository()
    repository.add("owner-1", _measurement(date(2026, 10, 14), 23))
    repository.add("owner-1", _measurement(date(2026, 10, 14), 23.4))

    latest = repository.latest_for_pet("owner-1", "pet-1")

    assert latest is not None
    assert latest.weight_kg == 23.4


def test_latest_weighing_is_private_to_the_owner_and_the_pet() -> None:
    repository = InMemoryWeightMeasurementRepository()
    repository.add("owner-1", _measurement(date(2026, 10, 14), 23))

    assert repository.latest_for_pet("owner-2", "pet-1") is None
    assert repository.latest_for_pet("owner-1", "pet-2") is None


# --- the chat ---------------------------------------------------------------


def _service(
    client: RecordingLLMClient, weights: InMemoryWeightMeasurementRepository | None
) -> SendChatMessageService:
    pets = InMemoryPetProfileRepository()
    pets.save(
        PetProfile(
            id="pet-1",
            owner_id="owner-1",
            name="Rex",
            species="Cane",
            sex="Maschio",
            weight_label="30 kg",
        )
    )
    return SendChatMessageService(
        InMemoryConversationRepository(),
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()),
        pets,
        weight_measurement_repository=weights,
    )


def _ask(service: SendChatMessageService) -> None:
    service.execute(
        SendChatMessageInput(
            owner_id="owner-1", pet_id="pet-1", user_message="Rex ha le feci molli da ieri"
        )
    )


def test_chat_uses_the_latest_weighing_with_its_date() -> None:
    client = RecordingLLMClient()
    weights = InMemoryWeightMeasurementRepository()
    weights.add("owner-1", _measurement(date(THIS_YEAR, 10, 14), 23))
    weights.add("owner-1", _measurement(date(THIS_YEAR, 8, 1), 21))

    _ask(_service(client, weights))

    prompt = client.requests[-1].user_prompt
    assert "Weight: 23 kg al 14 ottobre" in prompt
    assert "30 kg" not in prompt


def test_chat_falls_back_to_the_profile_weight_without_weighings() -> None:
    client = RecordingLLMClient()

    _ask(_service(client, InMemoryWeightMeasurementRepository()))

    assert "Weight: 30 kg" in client.requests[-1].user_prompt


def test_chat_without_a_weighing_source_keeps_the_profile_weight() -> None:
    client = RecordingLLMClient()

    _ask(_service(client, None))

    assert "Weight: 30 kg" in client.requests[-1].user_prompt


def test_chat_keeps_answering_when_the_weighings_cannot_be_read() -> None:
    class Broken:
        def latest_for_pet(self, owner_id: str, pet_id: str) -> WeightMeasurement | None:
            raise RuntimeError("table missing")

    client = RecordingLLMClient()

    _ask(_service(client, Broken()))  # type: ignore[arg-type]

    assert "Weight: 30 kg" in client.requests[-1].user_prompt


def test_a_pet_with_only_weighings_no_longer_gets_the_missing_weight_hint() -> None:
    client = RecordingLLMClient()
    pets = InMemoryPetProfileRepository()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Rex", species="Cane"))
    weights = InMemoryWeightMeasurementRepository()
    weights.add("owner-1", _measurement(date(THIS_YEAR, 10, 14), 23))
    service = SendChatMessageService(
        InMemoryConversationRepository(),
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()),
        pets,
        weight_measurement_repository=weights,
    )

    output = service.execute(
        SendChatMessageInput(
            owner_id="owner-1", pet_id="pet-1", user_message="Quante crocchette deve mangiare Rex?"
        )
    )

    assert "manca il peso" not in output.reply.content
    assert "Weight: 23 kg al 14 ottobre" in client.requests[-1].user_prompt


# --- one body condition in the chat -------------------------------------------


def _service_with_profile_condition(
    client: RecordingLLMClient,
    weights: InMemoryWeightMeasurementRepository | None,
    profile_condition: str | None,
    species: str = "Cane",
    breed: str | None = None,
) -> SendChatMessageService:
    pets = InMemoryPetProfileRepository()
    pets.save(
        PetProfile(
            id="pet-1",
            owner_id="owner-1",
            name="Rex",
            species=species,
            breed=breed,
            sex="Maschio",
            weight_label="30 kg",
            body_condition=profile_condition,
        )
    )
    return SendChatMessageService(
        InMemoryConversationRepository(),
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()),
        pets,
        weight_measurement_repository=weights,
    )


def _condition_lines(client: RecordingLLMClient) -> list[str]:
    return [
        line for line in client.requests[-1].user_prompt.splitlines() if "Body condition" in line
    ]


def test_chat_states_the_latest_weighing_condition_with_its_date_over_the_profile() -> None:
    client = RecordingLLMClient()
    weights = InMemoryWeightMeasurementRepository()
    weights.add("owner-1", _measurement(date(THIS_YEAR, 8, 1), 21, body_condition=2))
    weights.add("owner-1", _measurement(date(THIS_YEAR, 10, 14), 23, body_condition=4))

    _ask(_service_with_profile_condition(client, weights, "thin"))

    assert _condition_lines(client) == [
        "Body condition (weighed on 14 ottobre): slightly overweight"
    ]


def test_chat_uses_the_latest_weighing_that_recorded_a_condition() -> None:
    client = RecordingLLMClient()
    weights = InMemoryWeightMeasurementRepository()
    weights.add("owner-1", _measurement(date(THIS_YEAR, 8, 1), 21, body_condition=5))
    weights.add("owner-1", _measurement(date(THIS_YEAR, 10, 14), 23))  # no condition

    _ask(_service_with_profile_condition(client, weights, "thin"))

    prompt = client.requests[-1].user_prompt
    assert _condition_lines(client) == ["Body condition (weighed on 1 agosto): overweight"]
    assert "Weight: 23 kg al 14 ottobre" in prompt


def test_chat_falls_back_to_the_profile_condition_without_a_weighed_one() -> None:
    client = RecordingLLMClient()
    weights = InMemoryWeightMeasurementRepository()
    weights.add("owner-1", _measurement(date(THIS_YEAR, 10, 14), 23))  # no condition

    _ask(_service_with_profile_condition(client, weights, "thin"))

    assert _condition_lines(client) == ["Body condition (owner's estimate): thin"]


def test_chat_condition_survives_an_unreadable_weighing_source() -> None:
    class Broken:
        def latest_for_pet(self, owner_id: str, pet_id: str) -> WeightMeasurement | None:
            raise RuntimeError("table missing")

        def latest_with_body_condition_for_pet(
            self, owner_id: str, pet_id: str
        ) -> WeightMeasurement | None:
            raise RuntimeError("table missing")

    client = RecordingLLMClient()

    _ask(_service_with_profile_condition(client, Broken(), "normal"))  # type: ignore[arg-type]

    assert _condition_lines(client) == ["Body condition (owner's estimate): normal"]


def test_chat_has_no_condition_line_when_nobody_recorded_one() -> None:
    client = RecordingLLMClient()

    _ask(_service_with_profile_condition(client, InMemoryWeightMeasurementRepository(), None))

    assert _condition_lines(client) == []


@pytest.mark.parametrize(
    ("species", "breed", "has_condition"),
    [
        ("Cane", None, True),
        ("Gatto", None, True),
        ("Piccoli mammiferi", "Coniglio ariete", True),
        ("Piccoli mammiferi", "Criceto", False),
        ("Piccoli mammiferi", None, False),
        ("Uccello", None, False),
        ("Rettili e anfibi", None, False),
        ("Pesce", None, False),
    ],
)
def test_chat_reads_a_body_condition_only_for_species_with_a_guide(
    species: str, breed: str | None, has_condition: bool
) -> None:
    client = RecordingLLMClient()
    weights = InMemoryWeightMeasurementRepository()
    weights.add("owner-1", _measurement(date(THIS_YEAR, 10, 14), 23, body_condition=4))

    _ask(_service_with_profile_condition(client, weights, "thin", species=species, breed=breed))

    assert bool(_condition_lines(client)) is has_condition
