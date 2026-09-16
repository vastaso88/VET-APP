from fastapi import APIRouter

from apps.api.dependencies.container import get_container
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
