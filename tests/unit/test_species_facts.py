from test_chat_orchestrator import FakeLLMClient

from packages.core.application.services.chat_orchestrator import (
    ChatOrchestrator,
    ChatOrchestratorInput,
)
from packages.core.application.services.natural_answer_prompt import build_system_prompt
from packages.core.domain.conversation.request_kind import RequestKind
from packages.core.domain.pet_profile.species_facts import species_facts
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer


def test_facts_are_found_from_the_app_labels_and_the_breed() -> None:
    rabbit = species_facts("Piccoli mammiferi", "Coniglio nano")
    gecko = species_facts("Rettili e anfibi", "Geco leopardino")

    assert "ciecotrofi" in rabbit and "NORMAL" in rabbit
    assert "insectivorous" in gecko and "fruit or vegetables" in gecko
    assert species_facts("Cane", "Labrador") == ""
    assert species_facts("Piccoli mammiferi", "Criceto dorato") == ""


def test_facts_can_also_come_from_the_owners_notes() -> None:
    assert "ciecotrofi" in species_facts("Altro", None, "è un coniglio ariete di 2 anni")


def test_the_prompt_carries_the_facts_above_the_models_own_assumptions() -> None:
    prompt = build_system_prompt(
        RequestKind.DIRECT,
        may_ask=False,
        has_reference_material=False,
        species_facts=species_facts("Piccoli mammiferi", "Coniglio"),
    )

    assert "FACTS ABOUT THIS KIND OF ANIMAL" in prompt
    assert "these win" in prompt
    assert "ciecotrofi" in prompt
    assert "FACTS ABOUT" not in build_system_prompt(
        RequestKind.DIRECT, may_ask=False, has_reference_material=False
    )


def test_the_orchestrator_hands_the_facts_to_the_model_for_a_rabbit_and_a_gecko() -> None:
    for species, breed, expected in (
        ("Piccoli mammiferi", "Coniglio nano", "ciecotrofi"),
        ("Rettili e anfibi", "Geco leopardino", "insectivorous"),
    ):
        client = FakeLLMClient()
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
            ChatOrchestratorInput(
                user_message="cosa gli posso dare da mangiare?",
                species=species,
                breed=breed,
                pet_name="Fiocco",
            )
        )
        assert expected in client.requests[-1].system_prompt, species

    client = FakeLLMClient()
    ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
        ChatOrchestratorInput(user_message="cosa gli posso dare?", species="Cane", pet_name="Thor")
    )
    # No correction fact for a dog (the ethology paragraph of a direct
    # question is another layer, tested below).
    prompt = client.requests[-1].system_prompt
    assert "Rabbit:" not in prompt and "Leopard gecko" not in prompt


def test_the_ethology_layer_travels_only_with_direct_questions() -> None:
    # Repositioning (docs/product/11 §4, 2.4): dog, cat and rabbit ethology
    # with the body behind each position, for the "why" answers only.
    assert species_facts("Cane", "Labrador") == ""
    dog = species_facts("Cane", "Labrador", ethology=True)
    cat = species_facts("Gatto", None, ethology=True)
    rabbit = species_facts("Piccoli mammiferi", "Coniglio nano", ethology=True)

    assert "ESVCE and AVSAB" in dog and "dominance" in dog
    assert "ISFM" in cat and "not only" in cat
    assert "RWAF" in rabbit and "ciecotrofi" in rabbit
    assert species_facts("Piccoli mammiferi", "Criceto dorato", ethology=True) == ""

    for message, expected in (
        ("perché ringhia quando mi avvicino alla ciotola?", True),
        ("da ieri zoppica e non appoggia la zampa", False),
    ):
        client = FakeLLMClient()
        ChatOrchestrator(client, InMemoryEvidenceRetriever(), NoopPiiAnonymizer()).answer(
            ChatOrchestratorInput(user_message=message, species="Cane", pet_name="Thor")
        )
        assert ("Dog ethology" in client.requests[-1].system_prompt) is expected, message
