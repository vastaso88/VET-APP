from fastapi import APIRouter

from apps.api.dependencies.container import get_container
from apps.api.schemas.subscription import SelectPlanRequest
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
)
from packages.core.application.services.select_plan import SelectPlanInput

router = APIRouter(prefix="/subscription", tags=["subscription"])


@router.get("/status")
def get_subscription_status() -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.get_or_create_subscription_service().execute(
        GetOrCreateSubscriptionInput(owner_id=user.id, email=user.email)
    )
    return result.model_dump()


@router.post("/select-plan")
def select_plan(request: SelectPlanRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.select_plan_service().execute(
        SelectPlanInput(owner_id=user.id, plan=request.plan)
    )
    return result.model_dump()
