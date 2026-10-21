"""Which profile details the chat may know for which animal (2026-10-21)."""

import pytest

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.domain.pet_profile.species_rules import (
    PetKind,
    has_activity,
    has_body_condition,
    has_neutering,
    has_sex,
    has_weight,
    pet_kind,
    uses_breed_word,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
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


@pytest.mark.parametrize(
    ("species", "breed", "kind"),
    [
        ("Cane", "Labrador Retriever", PetKind.DOG),
        ("Gatto", None, PetKind.CAT),
        ("Piccoli mammiferi", "Coniglio nano", PetKind.RABBIT),
        ("Piccoli mammiferi", "Coniglio comune / meticcio", PetKind.RABBIT),
        ("Piccoli mammiferi", "Criceto siriano (Mesocricetus auratus)", PetKind.SMALL_MAMMAL),
        ("Uccello", "Cocorita (Melopsittacus undulatus)", PetKind.BIRD),
        ("Rettili e anfibi", "Drago barbuto (Pogona vitticeps)", PetKind.REPTILE),
        ("Rettili e anfibi", "Axolotl", PetKind.AMPHIBIAN),
        ("Rettili e anfibi", "Rana dagli occhi rossi (Agalychnis callidryas)", PetKind.AMPHIBIAN),
        ("Pesce", "Guppy", PetKind.FISH),
        ("Altro", "Cavallo", PetKind.LARGE_MAMMAL),
        ("Altro", "Oca domestica", PetKind.BIRD),
        ("Altro", "Tarantola (Theraphosidae)", PetKind.INVERTEBRATE),
        ("Altro", "Un animale mai visto", PetKind.UNKNOWN),
        ("rabbit", None, PetKind.SMALL_MAMMAL),
    ],
)
def test_kind_comes_from_the_category_and_the_chosen_species(
    species: str, breed: str | None, kind: PetKind
) -> None:
    assert pet_kind(species, breed) is kind


def test_dogs_and_cats_have_breeds_everything_else_a_species() -> None:
    assert uses_breed_word("Cane") and uses_breed_word("Gatto")
    for species in ("Piccoli mammiferi", "Uccello", "Rettili e anfibi", "Pesce", "Altro"):
        assert not uses_breed_word(species)


def test_rules_per_animal() -> None:
    assert not any(
        rule("Pesce")
        for rule in (has_sex, has_weight, has_neutering, has_body_condition, has_activity)
    )
    for species in ("Uccello", "Rettili e anfibi"):
        assert has_weight(species) and has_sex(species)
        assert not has_neutering(species)
        assert not has_body_condition(species)
        assert not has_activity(species)
    assert has_body_condition("Piccoli mammiferi", "Coniglio nano")
    assert not has_body_condition("Piccoli mammiferi", "Cavia")
    assert not has_activity("Piccoli mammiferi", "Coniglio nano")
    assert has_neutering("Piccoli mammiferi", "Furetto (Mustela putorius furo)")
    assert not has_neutering("Altro", "Mantide religiosa")
    assert has_body_condition("Cane") and has_activity("Cane") and has_neutering("Cane")
    assert has_body_condition("Gatto") and has_activity("Gatto")


def _prompt(**fields: object) -> str:
    client = RecordingLLMClient()
    orchestrator = ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer())
    orchestrator.answer(
        ChatOrchestratorInput(user_message="Come sta?", pet_name="Pico", **fields)  # type: ignore[arg-type]
    )
    return client.requests[-1].user_prompt


def test_a_bird_with_old_dog_style_details_is_described_without_them() -> None:
    prompt = _prompt(
        species="Uccello",
        breed="Cocorita (Melopsittacus undulatus)",
        is_sterilized=True,
        body_condition="overweight",
        activity_level="sedentary",
        dog_size_category="Media",
    )

    assert "Specific species: Cocorita (Melopsittacus undulatus)" in prompt
    assert "Breed:" not in prompt
    assert "Neutered/spayed" not in prompt
    assert "Body condition" not in prompt
    assert "Activity level" not in prompt
    assert "Size category" not in prompt


def test_a_dog_keeps_breed_and_all_its_details() -> None:
    prompt = _prompt(
        species="Cane",
        breed="Labrador",
        is_sterilized=True,
        body_condition="overweight",
        activity_level="sedentary",
        dog_size_category="Grande",
    )

    assert "Breed: Labrador" in prompt
    assert "Neutered/spayed: yes" in prompt
    assert "Body condition (owner's estimate): overweight" in prompt
    assert "Activity level: sedentary" in prompt
    assert "Size category: Grande" in prompt


def test_a_rabbit_has_a_body_condition_but_no_activity_level() -> None:
    prompt = _prompt(
        species="Piccoli mammiferi",
        breed="Coniglio nano",
        body_condition="thin",
        activity_level="active",
        is_sterilized=False,
    )

    assert "Body condition (owner's estimate): thin" in prompt
    assert "Activity level" not in prompt
    assert "Neutered/spayed: no" in prompt


def test_an_aquarium_has_no_sex_or_weight() -> None:
    prompt = _prompt(species="Pesce", sex="Sconosciuto", weight_label="0,4 kg")

    assert "Sex:" not in prompt
    assert "Weight:" not in prompt
