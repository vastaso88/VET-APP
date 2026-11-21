from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from apps.api.dependencies.container import get_container
from apps.api.request_language import request_language
from apps.api.schemas.subscription import SelectPlanRequest
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
)
from packages.core.application.services.select_plan import (
    PlanRequiresStorePurchaseError,
    SelectPlanInput,
)
from packages.core.domain.localization import translate

router = APIRouter(prefix="/subscription", tags=["subscription"])


@router.get("/status")
def get_subscription_status() -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.get_or_create_subscription_service().execute(
        GetOrCreateSubscriptionInput(
            owner_id=user.id, email=user.email, email_verified=getattr(user, "email_verified", None)
        )
    )
    return result.model_dump()


@router.post("/select-plan", response_model=None)
def select_plan(
    request: SelectPlanRequest, http_request: Request
) -> dict[str, object] | JSONResponse:
    container = get_container()
    user = container.auth_provider.get_current_user()
    if container.subscription_test_plan is None:
        # Paying needs a declared age; a declared minor also needs the
        # parent's-authorisation confirmation (403 age_required / guardian_required).
        container.age_gate_service().require_paid_plan(user.id)
    try:
        result = container.select_plan_service().execute(
            SelectPlanInput(owner_id=user.id, plan=request.plan)
        )
    except PlanRequiresStorePurchaseError:
        # Never a plan from a plain request: buy in the store, the backend
        # grants it after verifying (/billing/purchases/verify).
        return JSONResponse(
            status_code=409,
            content={
                "detail": "Plan changes require a verified App Store or Google Play purchase",
                "code": "plan_change_requires_store_purchase",
            },
        )
    body: dict[str, object] = result.model_dump()
    over = result.pets_over_limit
    if over is not None:
        body["code"] = "pets_over_plan_limit"
        body["message"] = translate(
            "plan_over_pet_limit",
            request_language(http_request),
            count=over.count,
            limit=over.limit,
            plan=over.plan.capitalize(),
        )
    if result.test_period:
        body["code"] = "subscription_test_period"
        body["message"] = (
            "Periodo di test: tutti gli account sono sul piano di prova e nessuno paga. "
            "Il piano non è stato modificato."
        )
    return body
