import pytest

from packages.core.application.services.report_chat_response import (
    ReportChatResponseInput,
    ReportChatResponseService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatResponseReportRepository,
    InMemoryConversationRepository,
)
from packages.shared.errors.base import ValidationError


def _seeded_conversation(repository: InMemoryConversationRepository) -> Conversation:
    conversation = Conversation(
        owner_id="owner-1",
        pet_id="pet-1",
        title="Chat for pet-1",
        messages=[
            ChatMessage(role="user", content="Il mio cane tossisce"),
            ChatMessage(role="assistant", content="Da quanto tempo lo noti?"),
        ],
    )
    return repository.save(conversation)


def test_reports_an_assistant_reply() -> None:
    conversation_repository = InMemoryConversationRepository()
    conversation = _seeded_conversation(conversation_repository)
    assistant_message = conversation.messages[1]
    service = ReportChatResponseService(
        conversation_repository, InMemoryChatResponseReportRepository()
    )

    result = service.execute(
        ReportChatResponseInput(
            reporter_owner_id="owner-1",
            conversation_id=conversation.id,
            message_id=assistant_message.id,
            reason="wrong_answer",
            details="Non ha senso per il mio caso",
        )
    )

    assert result.report.reported_answer == "Da quanto tempo lo noti?"
    assert result.report.pet_id == "pet-1"
    assert result.report.status == "reported"
    assert result.report.credited_bug_ref is None


def test_rejects_an_unknown_conversation() -> None:
    service = ReportChatResponseService(
        InMemoryConversationRepository(), InMemoryChatResponseReportRepository()
    )

    with pytest.raises(ValidationError):
        service.execute(
            ReportChatResponseInput(
                reporter_owner_id="owner-1", conversation_id="missing", message_id="msg-1"
            )
        )


def test_rejects_a_conversation_belonging_to_a_different_owner() -> None:
    conversation_repository = InMemoryConversationRepository()
    conversation = _seeded_conversation(conversation_repository)
    service = ReportChatResponseService(
        conversation_repository, InMemoryChatResponseReportRepository()
    )

    with pytest.raises(ValidationError):
        service.execute(
            ReportChatResponseInput(
                reporter_owner_id="someone-else",
                conversation_id=conversation.id,
                message_id=conversation.messages[1].id,
            )
        )


def test_rejects_an_unknown_message_id() -> None:
    conversation_repository = InMemoryConversationRepository()
    conversation = _seeded_conversation(conversation_repository)
    service = ReportChatResponseService(
        conversation_repository, InMemoryChatResponseReportRepository()
    )

    with pytest.raises(ValidationError):
        service.execute(
            ReportChatResponseInput(
                reporter_owner_id="owner-1",
                conversation_id=conversation.id,
                message_id="not-a-real-message",
            )
        )


def test_rejects_reporting_the_owners_own_message() -> None:
    # Reporting the app's own reply is the point; the owner's own message
    # has nothing to report.
    conversation_repository = InMemoryConversationRepository()
    conversation = _seeded_conversation(conversation_repository)
    user_message = conversation.messages[0]
    service = ReportChatResponseService(
        conversation_repository, InMemoryChatResponseReportRepository()
    )

    with pytest.raises(ValidationError):
        service.execute(
            ReportChatResponseInput(
                reporter_owner_id="owner-1",
                conversation_id=conversation.id,
                message_id=user_message.id,
            )
        )
