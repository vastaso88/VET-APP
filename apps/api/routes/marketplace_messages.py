"""The messages of the Mercatino. Writing needs a plan; reading one's own
conversations, marking them read, blocking and reporting do not: they are the
owner's own data and safety tools, and must keep working after the trial.

Every route reads the caller from the token. An id that is not the caller's
answers 404, exactly like one that does not exist."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from apps.api.dependencies.subscription import require_active_subscription
from packages.core.application.services.marketplace_messaging import (
    ConversationClosedError,
    ConversationNotFoundError,
    MarketplaceMessagingService,
)
from packages.core.domain.marketplace.messaging import (
    MESSAGE_MAX_LENGTH,
    ConversationReportReason,
)

router = APIRouter(prefix="/marketplace", tags=["marketplace-messages"])

MessageText = Annotated[str, Field(min_length=1, max_length=MESSAGE_MAX_LENGTH)]


class MessageRequest(BaseModel):
    text: MessageText


class ReportConversationRequest(BaseModel):
    reason: ConversationReportReason


def _service() -> MarketplaceMessagingService:
    return get_container().marketplace_messaging_service()


def _not_found() -> HTTPException:
    return HTTPException(status_code=404, detail="conversation_not_found")


def _closed() -> HTTPException:
    return HTTPException(status_code=409, detail="conversation_closed")


@router.post(
    "/listings/{listing_id}/conversations",
    dependencies=[Depends(require_active_subscription)],
)
def write_to_seller(listing_id: str, request: MessageRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    try:
        sent = _service().start_or_continue(
            listing_id, user.id, request.text, user.preferred_locale
        )
    except ConversationNotFoundError as exc:
        raise _not_found() from exc
    except ConversationClosedError as exc:
        raise _closed() from exc
    return sent.model_dump(mode="json")


@router.get("/listings/{listing_id}/conversation")
def my_conversation_about_listing(listing_id: str) -> dict[str, object]:
    user = get_container().auth_provider.get_current_user()
    return _service().find_for_listing(listing_id, user.id).model_dump(mode="json")


# The caller's own restriction by the moderation team, so the app can say it
# before they try. Nobody can ask about anyone else.
@router.get("/restriction")
def my_marketplace_restriction() -> dict[str, object]:
    user = get_container().auth_provider.get_current_user()
    restriction = _service().restriction_of(user.id)
    if restriction is None:
        return {"restricted": False, "reason": None, "since": None}
    return {
        "restricted": True,
        "reason": restriction.reason,
        "since": restriction.created_at.isoformat(),
    }


@router.get("/conversations")
def list_my_conversations() -> dict[str, object]:
    user = get_container().auth_provider.get_current_user()
    views = _service().list_conversations(user.id)
    return {
        "conversations": [view.model_dump(mode="json") for view in views],
        "unread_total": sum(view.unread_count for view in views),
    }


# Before "/conversations/{conversation_id}", or "unread-count" would be taken for an id.
@router.get("/conversations/unread-count")
def my_unread_count() -> dict[str, int]:
    user = get_container().auth_provider.get_current_user()
    return {"unread_total": _service().unread_total(user.id)}


@router.get("/conversations/{conversation_id}")
def read_conversation(conversation_id: str) -> dict[str, object]:
    user = get_container().auth_provider.get_current_user()
    try:
        return _service().thread(conversation_id, user.id).model_dump(mode="json")
    except ConversationNotFoundError as exc:
        raise _not_found() from exc


@router.post(
    "/conversations/{conversation_id}/messages",
    dependencies=[Depends(require_active_subscription)],
)
def send_message(conversation_id: str, request: MessageRequest) -> dict[str, object]:
    user = get_container().auth_provider.get_current_user()
    try:
        return _service().send(conversation_id, user.id, request.text).model_dump(mode="json")
    except ConversationNotFoundError as exc:
        raise _not_found() from exc
    except ConversationClosedError as exc:
        raise _closed() from exc


@router.post("/conversations/{conversation_id}/read")
def mark_conversation_read(conversation_id: str) -> dict[str, bool]:
    user = get_container().auth_provider.get_current_user()
    try:
        _service().mark_read(conversation_id, user.id)
    except ConversationNotFoundError as exc:
        raise _not_found() from exc
    return {"ok": True}


@router.post("/conversations/{conversation_id}/block")
def block_other_participant(conversation_id: str) -> dict[str, object]:
    user = get_container().auth_provider.get_current_user()
    try:
        view = _service().block(conversation_id, user.id)
    except ConversationNotFoundError as exc:
        raise _not_found() from exc
    return {"conversation": view.model_dump(mode="json")}


@router.delete("/conversations/{conversation_id}/block")
def unblock_other_participant(conversation_id: str) -> dict[str, object]:
    user = get_container().auth_provider.get_current_user()
    try:
        view = _service().unblock(conversation_id, user.id)
    except ConversationNotFoundError as exc:
        raise _not_found() from exc
    return {"conversation": view.model_dump(mode="json")}


@router.post("/conversations/{conversation_id}/report")
def report_conversation(
    conversation_id: str, request: ReportConversationRequest
) -> dict[str, bool]:
    user = get_container().auth_provider.get_current_user()
    try:
        _service().report(conversation_id, user.id, request.reason)
    except ConversationNotFoundError as exc:
        raise _not_found() from exc
    return {"ok": True}
