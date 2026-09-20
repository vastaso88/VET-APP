from fastapi import APIRouter

from apps.api.dependencies.container import get_container
from apps.api.schemas.chat_response_reports import (
    CreateChatResponseReportRequest,
    ResolveChatResponseReportRequest,
)
from packages.core.application.services.list_chat_response_reports import (
    ListChatResponseReportsInput,
)
from packages.core.application.services.report_chat_response import ReportChatResponseInput
from packages.core.application.services.resolve_chat_response_report import (
    ResolveChatResponseReportInput,
)
from packages.core.domain.feedback.models import ChatResponseReportStatus

router = APIRouter(prefix="/chat-response-reports", tags=["chat-response-reports"])


@router.post("")
def create_report(request: CreateChatResponseReportRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.report_chat_response_service().execute(
        ReportChatResponseInput(reporter_owner_id=user.id, **request.model_dump())
    )
    return result.model_dump()


@router.get("")
def list_reports(status: ChatResponseReportStatus | None = None) -> dict[str, object]:
    # Internal engineering-review listing (spec per marketing: a human
    # confirms which reports match a shipped fix before crediting a
    # reward) — not owner-scoped, no admin-role gate exists yet in this
    # codebase, same maturity level as the rest of the MVP.
    container = get_container()
    result = container.list_chat_response_reports_service().execute(
        ListChatResponseReportsInput(status=status)
    )
    return result.model_dump()


@router.put("/{report_id}/resolve")
def resolve_report(
    report_id: str, request: ResolveChatResponseReportRequest
) -> dict[str, object]:
    container = get_container()
    result = container.resolve_chat_response_report_service().execute(
        ResolveChatResponseReportInput(report_id=report_id, **request.model_dump())
    )
    return result.model_dump()
