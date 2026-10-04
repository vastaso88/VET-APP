from fastapi import APIRouter

from apps.api.dependencies.container import get_container
from apps.api.schemas.chat import SendChatMessageRequest
from packages.core.application.services.send_chat_message import SendChatMessageInput

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("")
def send_chat_message(request: SendChatMessageRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.send_chat_message_service().execute(
        SendChatMessageInput(
            owner_id=user.id, owner_display_name=user.display_name, **request.model_dump()
        )
    )
    return result.model_dump()
