from fastapi import APIRouter, Response

from apps.api.dependencies.container import get_container
from packages.core.application.services.delete_conversation import DeleteConversationInput
from packages.core.application.services.list_conversations import ListConversationsInput

router = APIRouter(prefix="/conversations", tags=["conversations"])


@router.get("")
def list_conversations() -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.list_conversations_service().execute(
        ListConversationsInput(owner_id=user.id)
    )
    return result.model_dump()


@router.delete("/{conversation_id}", status_code=204)
def delete_conversation(conversation_id: str) -> Response:
    container = get_container()
    user = container.auth_provider.get_current_user()
    container.delete_conversation_service().execute(
        DeleteConversationInput(owner_id=user.id, conversation_id=conversation_id)
    )
    return Response(status_code=204)
