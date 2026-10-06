from datetime import UTC, datetime

import pytest

from packages.core.application.ports.llm_client import LLMGenerationRequest, LLMResponse
from packages.core.application.services.list_conversations import (
    ListConversationsInput,
    ListConversationsService,
)
from packages.core.application.services.rename_conversation import (
    RenameConversationInput,
    RenameConversationService,
)
from packages.core.application.services.send_chat_message import migrate_legacy_title
from packages.core.application.services.vet_summary import (
    VET_SUMMARY_MARKER,
    VetSummaryInput,
    VetSummaryService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.conversation.title import (
    clean_custom_title,
    is_legacy_title,
    title_from_message,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer
from packages.shared.errors.base import ValidationError


class RecordingLLMClient:
    def __init__(self, content: str = "## Animale\n- Thor, cane") -> None:
        self.requests: list[LLMGenerationRequest] = []
        self._content = content

    def generate(self, request: LLMGenerationRequest) -> LLMResponse:
        self.requests.append(request)
        return LLMResponse(content=self._content, provider="fake", model="fake", token_count=1)


@pytest.mark.parametrize(
    ("message", "title"),
    [
        ("lo sbadiglio può essere un problema?", "Lo sbadiglio può essere un problema"),
        ("Mi spieghi il referto degli esami del sangue?", "Il referto degli esami del sangue"),
        ("ciao, volevo chiedere: è vero che i gatti vedono al buio?", "I gatti vedono al buio"),
        ("Toby è mogio", "Toby è mogio"),
        ("quante volte al giorno deve mangiare?", "Quante volte al giorno deve mangiare"),
        ("???", "Nuova conversazione"),
    ],
)
def test_a_title_is_derived_from_the_first_message(message: str, title: str) -> None:
    assert title_from_message(message) == title


def test_a_long_message_is_cut_at_a_word_within_forty_characters() -> None:
    title = title_from_message(
        "da due giorni zoppica dalla zampa posteriore dopo le passeggiate, mangia normale"
    )

    assert len(title) <= 40
    assert title.endswith("…")
    assert title.startswith("Da due giorni zoppica")


def test_the_owners_own_title_is_tidied_and_capped() -> None:
    assert clean_custom_title("  Esami   di\tsettembre \x07 ") == "Esami di settembre"
    assert len(clean_custom_title("x" * 200)) <= 60
    with pytest.raises(ValueError):
        clean_custom_title("   ")


def test_legacy_titles_are_recognised() -> None:
    assert is_legacy_title("Chat for 7f3a-pet")
    assert is_legacy_title("")
    assert not is_legacy_title("Esami del sangue")


def _conversation(title: str = "Chat for pet-1", owner: str = "owner-1") -> Conversation:
    return Conversation(
        owner_id=owner,
        pet_id="pet-1",
        title=title,
        messages=[
            ChatMessage(role="user", content="spiegami il referto degli esami del sangue"),
            ChatMessage(
                role="assistant",
                content="Ho letto «Esami del sangue» del 12 settembre 2026.\n\nTutto nella norma.",
            ),
        ],
    )


def test_a_legacy_title_is_replaced_when_the_conversation_is_listed_and_persisted() -> None:
    repository = InMemoryConversationRepository()
    repository.save(_conversation())

    result = ListConversationsService(repository).execute(
        ListConversationsInput(owner_id="owner-1")
    )

    [conversation] = result.conversations
    assert conversation.title == "Il referto degli esami del sangue"
    assert repository.get(conversation.id) is not None
    assert repository.get(conversation.id).title == "Il referto degli esami del sangue"  # type: ignore[union-attr]


def test_a_legacy_conversation_without_messages_keeps_its_title_for_now() -> None:
    conversation = Conversation(owner_id="o", pet_id="p", title="Chat for p")

    assert migrate_legacy_title(conversation).title == "Chat for p"


def test_the_owner_can_rename_a_conversation_but_not_someone_elses() -> None:
    repository = InMemoryConversationRepository()
    conversation = repository.save(_conversation(title="Esami"))
    service = RenameConversationService(repository)

    renamed = service.execute(
        RenameConversationInput(
            owner_id="owner-1", conversation_id=conversation.id, title="  Esami di   settembre "
        )
    )

    assert renamed.conversation.title == "Esami di settembre"
    assert repository.get(conversation.id).title == "Esami di settembre"  # type: ignore[union-attr]
    with pytest.raises(ValidationError, match="not found"):
        service.execute(
            RenameConversationInput(owner_id="intruder", conversation_id=conversation.id, title="x")
        )
    with pytest.raises(ValidationError, match="invalid_title"):
        service.execute(
            RenameConversationInput(owner_id="owner-1", conversation_id=conversation.id, title=" ")
        )


def _summary_service(client: RecordingLLMClient) -> tuple[VetSummaryService, Conversation]:
    conversations = InMemoryConversationRepository()
    pets = InMemoryPetProfileRepository()
    pets.save(
        PetProfile(
            id="pet-1",
            owner_id="owner-1",
            name="Thor",
            species="Cane",
            breed="Labrador",
            age_years=12,
            notes="Chiamare Mario Rossi al 333 1234567 per urgenze",
        )
    )
    conversation = _conversation()
    conversation.messages[
        0
    ].content = (
        "Sono Mario Rossi, spiegami il referto degli esami del sangue, il mio numero è 333 1234567"
    )
    conversation.messages[0].created_at = datetime(2026, 10, 1, 9, 0, tzinfo=UTC)
    conversations.save(conversation)
    return (
        VetSummaryService(conversations, pets, client, RuleBasedPiiAnonymizer()),
        conversation,
    )


def test_the_vet_summary_is_framed_as_generated_and_names_the_documents_read() -> None:
    client = RecordingLLMClient()
    service, conversation = _summary_service(client)

    result = service.execute(
        VetSummaryInput(
            owner_id="owner-1", conversation_id=conversation.id, owner_names=["Mario Rossi"]
        )
    )

    [request] = client.requests
    assert VET_SUMMARY_MARKER in request.system_prompt
    assert "«Esami del sangue» del 12 settembre 2026" in request.user_prompt
    assert "Thor" in request.user_prompt
    # The owner's name and phone never leave for the provider.
    assert "Mario" not in request.user_prompt and "Rossi" not in request.user_prompt
    assert "333 1234567" not in request.user_prompt
    assert result.summary.startswith("# Riassunto per il veterinario — Thor (Cane)")
    assert "Non è una diagnosi" in result.summary
    assert "iniziata il 1 ottobre 2026" in result.summary
    assert "## Animale" in result.summary
    assert result.summary.rstrip().endswith("proprietario è incluso.")


def test_the_vet_summary_is_owner_scoped_and_needs_a_message() -> None:
    service, conversation = _summary_service(RecordingLLMClient())

    with pytest.raises(ValidationError, match="not found"):
        service.execute(VetSummaryInput(owner_id="intruder", conversation_id=conversation.id))

    repository = InMemoryConversationRepository()
    empty = repository.save(Conversation(owner_id="owner-1", pet_id="pet-1", title="x"))
    with pytest.raises(ValidationError, match="conversation_empty"):
        VetSummaryService(
            repository,
            InMemoryPetProfileRepository(),
            RecordingLLMClient(),
            RuleBasedPiiAnonymizer(),
        ).execute(VetSummaryInput(owner_id="owner-1", conversation_id=empty.id))
