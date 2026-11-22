"""QK-04: the vet summary reads the conversation once and the pet once.

Before, the route read both only to build the list of names to redact and the
service read them again. The service now builds the list itself from the signed-in
owner's display name; the checks (other owner's chat, missing, empty), the
anonymization and the documents cited stay as they were.
"""

import pytest

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.vet_summary import VetSummaryInput, VetSummaryService
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer
from packages.shared.errors.base import ValidationError


class _CountingConversations(InMemoryConversationRepository):
    def __init__(self) -> None:
        super().__init__()
        self.reads = 0

    def get(self, conversation_id: str) -> Conversation | None:
        self.reads += 1
        return super().get(conversation_id)


class _CountingPets(InMemoryPetProfileRepository):
    def __init__(self) -> None:
        super().__init__()
        self.reads = 0

    def get(self, pet_id: str) -> PetProfile | None:
        self.reads += 1
        return super().get(pet_id)


class _FakeLLM:
    def __init__(self) -> None:
        self.requests: list[LLMGenerationRequest] = []

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(
            content="## Animale\n- Thor", provider="fake", model="fake", token_count=1
        )


def _setup(
    *, messages: list[ChatMessage] | None = None
) -> tuple[VetSummaryService, _CountingConversations, _CountingPets, _FakeLLM, Conversation]:
    conversations = _CountingConversations()
    pets = _CountingPets()
    pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Thor", species="Cane"))
    conversation = Conversation(
        owner_id="owner-1",
        pet_id="pet-1",
        title="Esami",
        messages=messages
        if messages is not None
        else [
            ChatMessage(role="user", content="Sono Anna Bianchi, spiegami il referto"),
            ChatMessage(
                role="assistant",
                content="Ho letto «Esami del sangue» del 12 settembre 2026.\n\nTutto nella norma.",
            ),
        ],
    )
    conversations.save(conversation)
    llm = _FakeLLM()
    service = VetSummaryService(conversations, pets, llm, RuleBasedPiiAnonymizer())
    conversations.reads = 0  # the save above is setup, not the request
    return service, conversations, pets, llm, conversation


def test_a_valid_summary_reads_the_conversation_once_and_the_pet_once() -> None:
    service, conversations, pets, llm, conversation = _setup()

    service.execute(
        VetSummaryInput(
            owner_id="owner-1",
            conversation_id=conversation.id,
            owner_display_name="Anna Bianchi",
        )
    )

    assert conversations.reads == 1
    assert pets.reads == 1
    assert len(llm.requests) == 1


def test_the_owner_name_is_redacted_and_the_documents_are_kept() -> None:
    service, _, _, llm, conversation = _setup()

    service.execute(
        VetSummaryInput(
            owner_id="owner-1",
            conversation_id=conversation.id,
            owner_display_name="Anna Bianchi",
        )
    )

    [request] = llm.requests
    assert "Anna" not in request.user_prompt and "Bianchi" not in request.user_prompt
    assert "«Esami del sangue» del 12 settembre 2026" in request.user_prompt


def test_an_owner_named_like_the_pet_is_not_redacted() -> None:
    # Same rule as the chat: a name shared with the pet would blank the pet itself.
    service, _, _, llm, conversation = _setup()

    service.execute(
        VetSummaryInput(
            owner_id="owner-1", conversation_id=conversation.id, owner_display_name="Thor"
        )
    )

    assert "Thor" in llm.requests[0].user_prompt


def test_explicit_owner_names_still_win_over_the_display_name() -> None:
    service, _, _, llm, conversation = _setup()

    service.execute(
        VetSummaryInput(
            owner_id="owner-1",
            conversation_id=conversation.id,
            owner_names=["Anna Bianchi"],
        )
    )

    assert "Bianchi" not in llm.requests[0].user_prompt


def test_user_b_gets_not_found_and_nothing_reaches_the_provider() -> None:
    service, conversations, pets, llm, conversation = _setup()

    with pytest.raises(ValidationError, match="conversation not found"):
        service.execute(
            VetSummaryInput(
                owner_id="owner-b", conversation_id=conversation.id, owner_display_name="Bea Verdi"
            )
        )

    assert conversations.reads == 1
    assert pets.reads == 0  # a stranger's chat never even loads its pet
    assert llm.requests == []


def test_a_missing_conversation_looks_the_same_as_someone_elses() -> None:
    service, _, pets, llm, _ = _setup()

    with pytest.raises(ValidationError, match="conversation not found"):
        service.execute(VetSummaryInput(owner_id="owner-1", conversation_id="missing"))

    assert pets.reads == 0
    assert llm.requests == []


def test_an_empty_conversation_is_refused_before_pet_and_model() -> None:
    service, _, pets, llm, conversation = _setup(messages=[])

    with pytest.raises(ValidationError, match="conversation_empty"):
        service.execute(VetSummaryInput(owner_id="owner-1", conversation_id=conversation.id))

    assert pets.reads == 0
    assert llm.requests == []
