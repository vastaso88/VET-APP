from fastapi import APIRouter

from apps.api.dependencies.container import get_container
from apps.api.schemas.chat_response_reports import (
    CreateChatResponseReportRequest,
    ResolveChatResponseReportRequest,
)
from packages.bootstrap.container import ApplicationContainer
from packages.core.application.services.list_chat_response_reports import (
    ListChatResponseReportsInput,
)
from packages.core.application.services.report_chat_response import ReportChatResponseInput
from packages.core.application.services.resolve_chat_response_report import (
    ResolveChatResponseReportInput,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.feedback.models import ChatResponseReportStatus
from packages.shared.errors.base import AuthenticationError

router = APIRouter(prefix="/chat-response-reports", tags=["chat-response-reports"])

# Never returned to a client: the pseudonym is only useful server-side, and
# the legacy clear id must not travel at all.
_REPORTER_FIELDS = {"reporter_ref", "reporter_owner_id"}


def _require_developer(container: ApplicationContainer) -> None:
    """Reports hold other people's (anonymized) chat replies: reviewing
    them is for the engineering allowlist only — a signed-in owner must
    not be able to read anyone else's report through this API.
    """
    user = container.auth_provider.get_current_user()
    if user.email.strip().lower() not in container.developer_emails:
        raise AuthenticationError("not allowed to review chat response reports")


@router.post("")
def create_report(request: CreateChatResponseReportRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.report_chat_response_service().execute(
        ReportChatResponseInput(reporter_owner_id=user.id, **request.model_dump())
    )
    return {"report": result.report.model_dump(exclude=_REPORTER_FIELDS)}


@router.delete("/mine")
def erase_my_reports() -> dict[str, object]:
    """Erasure on request: removes every report the signed-in owner made."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    erased = container.chat_response_report_maintenance_service().erase_for_owner(user.id)
    return {"erased": erased}


@router.get("")
def list_reports(status: ChatResponseReportStatus | None = None) -> dict[str, object]:
    container = get_container()
    _require_developer(container)
    result = container.list_chat_response_reports_service().execute(
        ListChatResponseReportsInput(status=status)
    )
    return {
        "reports": [report.model_dump(exclude=_REPORTER_FIELDS) for report in result.reports]
    }


@router.put("/{report_id}/resolve")
def resolve_report(
    report_id: str, request: ResolveChatResponseReportRequest
) -> dict[str, object]:
    container = get_container()
    _require_developer(container)
    result = container.resolve_chat_response_report_service().execute(
        ResolveChatResponseReportInput(report_id=report_id, **request.model_dump())
    )
    return {"report": result.report.model_dump(exclude=_REPORTER_FIELDS)}


@router.post("/maintenance")
def run_maintenance() -> dict[str, object]:
    """Retention job (12 months after the outcome, then counters only) —
    idempotent, meant to be called on a schedule."""
    container = get_container()
    _require_developer(container)
    result = container.chat_response_report_maintenance_service().run(utc_now())
    return result.model_dump()
