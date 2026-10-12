"""Editing a sent message (build 28): the conversation is cut at that
message, the working state goes back to what it was there, and the
assistant answers the edited text through the usual path."""

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container, reset_container
from packages.core.application.services.chat_orchestrator import (
    ChatOrchestratorInput,
    ChatOrchestratorResult,
)
from packages.core.application.services.edit_chat_message import (
    EditChatMessageInput,
    EditChatMessageService,
)
from packages.core.application.services.send_chat_message import (
    SendChatMessageInput,
    SendChatMessageOutput,
    SendChatMessageService,
)
from packages.core.domain.conversation.attachment import ChatAttachment
from packages.core.domain.conversation.states import ConversationState
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatAttachmentRepository,
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
)
from packages.shared.errors.base import ValidationError


class ScriptedOrchestrator:
    """Answers "Risposta a: <message>", and on a message containing
    "convulsioni" asks the safety question (awaiting a clarification)."""

    def __init__(self) -> None:
        self.inputs: list[ChatOrchestratorInput] = []

    def answer(self, data: ChatOrchestratorInput) -> ChatOrchestratorResult:
        self.inputs.append(data)
        if "convulsioni" in data.user_message:
            return ChatOrchestratorResult(
                answer="Da quanto durano?",
                mode="safety_clarification",
                confidence="low",
                ai_generated=False,
                provider="rule-based",
                model="safety",
                awaiting_safety_clarification=True,
                safety_clarification_category="seizure",
            )
        return ChatOrchestratorResult(
            answer=f"Risposta a: {data.user_message}",
            mode="natural",
            confidence="medium",
            ai_generated=True,
            provider="fake",
            model="fake",
            state=ConversationState.NO_RELEVANT_SOURCES,
        )


class Harness:
    def __init__(self) -> None:
        self.pets = InMemoryPetProfileRepository()
        self.pets.save(PetProfile(id="pet-1", owner_id="owner-1", name="Birba", species="Cane"))
        self.conversations = InMemoryConversationRepository()
        self.attachments = InMemoryChatAttachmentRepository()
        self.orchestrator = ScriptedOrchestrator()
        self.send_service = SendChatMessageService(
            self.conversations,
            self.orchestrator,  # type: ignore[arg-type]
            self.pets,
            attachment_repository=self.attachments,
        )
        self.edit_service = EditChatMessageService(self.conversations, self.send_service)

    def send(
        self,
        text: str,
        client_id: str,
        conversation_id: str | None = None,
        attachment_id: str | None = None,
    ) -> SendChatMessageOutput:
        return self.send_service.execute(
            SendChatMessageInput(
                owner_id="owner-1",
                pet_id="pet-1",
                conversation_id=conversation_id,
                user_message=text,
                client_message_id=client_id,
                attachment_id=attachment_id,
            )
        )

    def edit(
        self,
        conversation_id: str,
        message_id: str,
        text: str,
        client_id: str,
        owner: str = "owner-1",
    ) -> SendChatMessageOutput:
        return self.edit_service.execute(
            EditChatMessageInput(
                owner_id=owner,
                conversation_id=conversation_id,
                message_id=message_id,
                user_message=text,
                client_message_id=client_id,
            )
        )

    def contents(self, conversation_id: str) -> list[str]:
        conversation = self.conversations.get(conversation_id)
        assert conversation is not None
        return [message.content for message in conversation.messages]


def _three_turns(h: Harness) -> str:
    first = h.send("perché mastica le scarpe?", "u1")
    conversation_id = first.conversation.id
    h.send("e le ciabatte?", "u2", conversation_id)
    h.send("grazie", "u3", conversation_id)
    return conversation_id


def test_editing_a_message_drops_it_and_everything_after_then_answers_again() -> None:
    h = Harness()
    conversation_id = _three_turns(h)

    result = h.edit(conversation_id, "u2", "e i calzini?", "u2-edit")

    assert h.contents(conversation_id) == [
        "perché mastica le scarpe?",
        "Risposta a: perché mastica le scarpe?",
        "e i calzini?",
        "Risposta a: e i calzini?",
    ]
    assert result.reply.content == "Risposta a: e i calzini?"
    # The model saw only the turns kept before the edited message.
    history = [m.content for m in h.orchestrator.inputs[-1].conversation_history]
    assert history == ["perché mastica le scarpe?", "Risposta a: perché mastica le scarpe?"]


def test_a_message_can_be_found_by_its_server_id_too() -> None:
    h = Harness()
    conversation_id = _three_turns(h)
    stored = h.conversations.get(conversation_id)
    assert stored is not None
    server_id = stored.messages[4].id  # "grazie"

    h.edit(conversation_id, server_id, "grazie mille", "u3-edit")

    assert h.contents(conversation_id)[-2:] == ["grazie mille", "Risposta a: grazie mille"]


def test_only_the_owner_can_edit() -> None:
    h = Harness()
    conversation_id = _three_turns(h)

    with pytest.raises(ValidationError, match="conversation not found"):
        h.edit(conversation_id, "u2", "intruso", "x", owner="someone-else")
    assert len(h.contents(conversation_id)) == 6


def test_an_unknown_or_assistant_message_cannot_be_edited() -> None:
    h = Harness()
    conversation_id = _three_turns(h)
    stored = h.conversations.get(conversation_id)
    assert stored is not None

    with pytest.raises(ValidationError, match="message not found"):
        h.edit(conversation_id, "does-not-exist", "x", "e1")
    with pytest.raises(ValidationError, match="message not found"):
        h.edit(conversation_id, stored.messages[1].id, "x", "e2")


def test_the_state_goes_back_to_what_it_was_at_the_edited_message() -> None:
    h = Harness()
    first = h.send("ha avuto le convulsioni", "u1")
    conversation_id = first.conversation.id
    assert first.awaiting_safety_clarification is True
    h.send("pochi secondi", "u2", conversation_id)
    h.send("ora dorme", "u3", conversation_id)

    # Editing the reply to the safety question: that question is pending again.
    h.edit(conversation_id, "u2", "quasi un minuto", "u2-edit")

    seen = h.orchestrator.inputs[-1]
    assert seen.awaiting_safety_clarification is True
    assert seen.safety_clarification_category == "seizure"


def test_editing_the_first_message_starts_from_a_fresh_state() -> None:
    h = Harness()
    first = h.send("ha avuto le convulsioni", "u1")
    conversation_id = first.conversation.id

    h.edit(conversation_id, "u1", "perché mastica le scarpe?", "u1-edit")

    seen = h.orchestrator.inputs[-1]
    assert seen.awaiting_safety_clarification is False
    assert seen.conversation_history == []


def test_a_retry_of_an_edit_returns_the_same_answer_without_editing_twice() -> None:
    h = Harness()
    conversation_id = _three_turns(h)
    first = h.edit(conversation_id, "u2", "e i calzini?", "u2-edit")
    calls = len(h.orchestrator.inputs)

    retry = h.edit(conversation_id, "u2", "e i calzini?", "u2-edit")

    assert len(h.orchestrator.inputs) == calls
    assert retry.reply.id == first.reply.id
    assert len(h.contents(conversation_id)) == 4


def test_the_attachment_is_kept_and_the_text_may_go() -> None:
    h = Harness()
    h.attachments.save(
        ChatAttachment(
            id="att-1",
            owner_id="owner-1",
            pet_id="pet-1",
            storage_key="att-1",
            content_type="image/jpeg",
            original_filename="foto.jpg",
            analysis="Un cane sdraiato con una zampa sollevata.",
        )
    )
    first = h.send("guarda la zampa", "u1", attachment_id="att-1")
    conversation_id = first.conversation.id

    h.edit(conversation_id, "u1", "", "u1-edit")

    stored = h.conversations.get(conversation_id)
    assert stored is not None
    assert stored.messages[0].content == ""
    assert stored.messages[0].attachment_id == "att-1"
    assert h.orchestrator.inputs[-1].photo_context == "Un cane sdraiato con una zampa sollevata."


def test_an_empty_edit_without_attachment_is_refused() -> None:
    h = Harness()
    conversation_id = _three_turns(h)

    with pytest.raises(ValidationError, match="must not be empty"):
        h.edit(conversation_id, "u2", "   ", "e1")


def test_the_automatic_title_follows_an_edited_first_message() -> None:
    h = Harness()
    first = h.send("perché mastica le scarpe?", "u1")
    conversation_id = first.conversation.id
    assert first.conversation.title == "Mastica le scarpe"

    result = h.edit(conversation_id, "u1", "perché abbaia di notte?", "u1-edit")

    assert result.conversation.title == "Abbaia di notte"


def test_a_title_the_owner_chose_is_kept() -> None:
    h = Harness()
    first = h.send("perché mastica le scarpe?", "u1")
    conversation_id = first.conversation.id
    stored = h.conversations.get(conversation_id)
    assert stored is not None
    stored.title = "Birba e le scarpe"
    h.conversations.save(stored)

    result = h.edit(conversation_id, "u1", "perché abbaia di notte?", "u1-edit")

    assert result.conversation.title == "Birba e le scarpe"


def test_the_route_edits_through_the_api() -> None:
    reset_container()
    client = TestClient(app)
    try:
        container = get_container()
        user = container.auth_provider.get_current_user()
        container.pet_profile_repository.save(
            PetProfile(id="pet-api", owner_id=user.id, name="Birba", species="Cane")
        )
        sent = client.post(
            "/chat",
            json={"pet_id": "pet-api", "user_message": "ciao", "client_message_id": "c1"},
        ).json()
        conversation_id = sent["conversation"]["id"]

        edited = client.put(
            f"/conversations/{conversation_id}/messages/c1",
            json={"user_message": "buongiorno", "client_message_id": "c1-edit"},
        )

        assert edited.status_code == 200
        body = edited.json()
        assert [m["content"] for m in body["conversation"]["messages"]][0] == "buongiorno"
        assert len(body["conversation"]["messages"]) == 2
        missing = client.put(
            f"/conversations/{conversation_id}/messages/nope",
            json={"user_message": "x", "client_message_id": "c2"},
        )
        assert missing.status_code == 400
    finally:
        reset_container()
