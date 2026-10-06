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
    assert "FACTS ABOUT" not in client.requests[-1].system_prompt
