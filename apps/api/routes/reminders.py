from fastapi import APIRouter, Depends

from apps.api.dependencies.container import get_container
from apps.api.dependencies.subscription import require_active_subscription
from apps.api.schemas.reminders import CreateReminderRequest
from packages.core.application.services.create_reminder import CreateReminderInput
from packages.core.application.services.list_reminders import ListRemindersInput

router = APIRouter(prefix="/reminders", tags=["reminders"])


@router.get("")
def list_reminders() -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.list_reminders_service().execute(ListRemindersInput(owner_id=user.id))
    return result.model_dump()


@router.post("", dependencies=[Depends(require_active_subscription)])
def create_reminder(request: CreateReminderRequest) -> dict[str, object]:
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.create_reminder_service().execute(
        CreateReminderInput(owner_id=user.id, **request.model_dump())
    )
    return result.model_dump()
