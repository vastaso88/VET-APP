import logging

from fastapi import APIRouter, HTTPException

from apps.api.dependencies.container import get_container
from apps.api.routes.admin import _require_admin

logger = logging.getLogger("vetgpt.admin.llm_usage")

router = APIRouter(prefix="/admin/llm-usage", tags=["admin"])


@router.get("")
def llm_usage() -> dict[str, object]:
    """What the AI costs, for the portal's "AI usage" page: today's spend against
    the euro cap, the month against the account's credits, usage per model, the
    last 30 days, the Sonnet answers and the Groq reserve calls of today.
    Aggregates from the usage ledger: no owner, no text, no personal data. Same
    admin protection as the other portal routes (a normal user gets 403)."""
    _require_admin()
    try:
        report = get_container().llm_usage_report_service().report()
    except Exception:  # noqa: BLE001 - never hand the ledger's error to the client
        logger.exception("admin llm usage: could not read the usage ledger")
        raise HTTPException(status_code=503, detail="The usage ledger is not available") from None
    return report.model_dump(mode="json")
