from fastapi import APIRouter, Depends, Header, Query, Response

from apps.api.dependencies.container import get_container
from apps.api.dependencies.subscription import allowlist_email, require_active_subscription
from apps.api.schemas.conversations import EditChatMessageRequest, RenameConversationRequest
from packages.core.application.services.delete_conversation import DeleteConversationInput
from packages.core.application.services.edit_chat_message import EditChatMessageInput
from packages.core.application.services.list_conversations import (
    DEFAULT_PAGE_SIZE,
    MAX_PAGE_SIZE,
    GetConversationInput,
    ListConversationPageInput,
    ListConversationsInput,
)
from packages.core.application.services.mark_not_helpful import MarkNotHelpfulInput
from packages.core.application.services.rename_conversation import RenameConversationInput
from packages.core.application.services.vet_summary import VetSummaryInput
from packages.core.domain.common.language import resolve_language
from packages.core.domain.conversation.models import public_message

router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.get("")
def list_conversations() -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.list_conversations_service().execute(
        ListConversationsInput(owner_id=user.id)
    )
    return {"conversations": [c.public_dump() for c in result.conversations]}


@router.get("/summaries")
def list_conversation_summaries(
    limit: int = Query(default=DEFAULT_PAGE_SIZE, ge=1, le=MAX_PAGE_SIZE),
    cursor: str | None = Query(default=None, max_length=300),
) -> dict[str, object]:
    """The owner's chat list without the messages (QK-12): id, pet, title, last activity,
    a short preview of the last message. Newest activity first; `next_cursor` is
    opaque and null on the last page. The full history stays on GET /conversations
    for the apps already installed; the messages of one chat are on GET /conversations/{id}."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    page = container.list_conversations_service().list_page(
        ListConversationPageInput(owner_id=user.id, limit=limit, cursor=cursor)
    )
    return {
        "conversations": [item.model_dump(mode="json") for item in page.items],
        "next_cursor": page.next_cursor,
    }


@router.get("/{conversation_id}")
def get_conversation(conversation_id: str) -> dict[str, object]:
    """One of the owner's conversations with its messages (the app opening a chat)."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.list_conversations_service().get_detail(
        GetConversationInput(owner_id=user.id, conversation_id=conversation_id)
    )
    return {"conversation": result.conversation.public_dump()}


@router.patch("/{conversation_id}")
def rename_conversation(
    conversation_id: str, request: RenameConversationRequest
) -> dict[str, object]:
    """The owner's own title for a conversation (validated and tidied)."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.rename_conversation_service().execute(
        RenameConversationInput(
            owner_id=user.id, conversation_id=conversation_id, title=request.title
        )
    )
    return {"id": result.conversation.id, "title": result.conversation.title}


@router.put(
    "/{conversation_id}/messages/{message_id}",
    dependencies=[Depends(require_active_subscription)],
)
def edit_message(
    conversation_id: str,
    message_id: str,
    request: EditChatMessageRequest,
    accept_language: str | None = Header(default=None),
) -> dict[str, object]:
    """Replaces one of the owner's messages and everything after it, then
    answers again. Same response body as POST /chat."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.edit_chat_message_service().execute(
        EditChatMessageInput(
            owner_id=user.id,
            conversation_id=conversation_id,
            message_id=message_id,
            user_message=request.user_message,
            client_message_id=request.client_message_id,
            owner_display_name=user.display_name,
            language=resolve_language(request.language, accept_language),
        )
    )
    body = result.model_dump(exclude={"conversation", "reply"})
    body["conversation"] = result.conversation.public_dump()
    body["reply"] = public_message(result.reply)
    return body


@router.post(
    "/{conversation_id}/messages/{message_id}/not-helpful",
    dependencies=[Depends(require_active_subscription)],
)
def mark_not_helpful(conversation_id: str, message_id: str) -> dict[str, bool]:
    """ "Non mi ha aiutato" under a health answer (plan "fratello maggiore"):
    the next health answer of this conversation is written with more care.
    Idempotent; costs no question of the daily allowance."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    container.mark_not_helpful_service().execute(
        MarkNotHelpfulInput(
            owner_id=user.id, conversation_id=conversation_id, message_id=message_id
        )
    )
    return {"recorded": True}


@router.get("/{conversation_id}/summary", dependencies=[Depends(require_active_subscription)])
def conversation_summary(
    conversation_id: str, accept_language: str | None = Header(default=None)
) -> dict[str, object]:
    """A structured summary of the conversation to hand to the vet:
    generated by the assistant, not a diagnosis (it says so itself)."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.vet_summary_service().execute(
        VetSummaryInput(
            owner_id=user.id,
            conversation_id=conversation_id,
            language=resolve_language(None, accept_language),
            quota_exempt=allowlist_email(user) in container.developer_emails,
            owner_display_name=user.display_name,
        )
    )
    return {"summary": result.summary, "generated_at": result.generated_at.isoformat()}


@router.delete("/{conversation_id}", status_code=204)
def delete_conversation(conversation_id: str) -> Response:
    container = get_container()
    user = container.auth_provider.get_current_user()
    container.delete_conversation_service().execute(
        DeleteConversationInput(owner_id=user.id, conversation_id=conversation_id)
    )
    return Response(status_code=204)
