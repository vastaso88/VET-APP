from fastapi import APIRouter, Header

from apps.api.dependencies.container import get_container
from apps.api.schemas.chat import SendChatMessageRequest
from packages.core.application.services.send_chat_message import SendChatMessageInput
from packages.core.domain.common.language import resolve_language
from packages.shared.errors.base import AuthenticationError

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("")
def send_chat_message(
    request: SendChatMessageRequest,
    accept_language: str | None = Header(default=None),
) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    fields = request.model_dump(exclude={"language", "response_locale"})
    result = container.send_chat_message_service().execute(
        SendChatMessageInput(
            owner_id=user.id,
            owner_email=user.email,
            owner_display_name=user.display_name,
            language=resolve_language(request.response_locale or request.language, accept_language),
            **fields,
        )
    )
    return result.model_dump()


@router.post("/maintenance")
def run_chat_usage_maintenance() -> dict[str, object]:
    """Retention for the model-usage ledger and the answer cache (build
    33): idempotent, meant to be called on a schedule. Developer accounts
    only, like the other maintenance route."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    if user.email.strip().lower() not in container.developer_emails:
        raise AuthenticationError("developer access required")
    return container.chat_usage_maintenance_service().run().model_dump()
