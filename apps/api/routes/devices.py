from fastapi import APIRouter
from pydantic import BaseModel, Field

from apps.api.dependencies.container import get_container
from packages.core.application.services.register_device import RegisterDeviceInput

router = APIRouter(prefix="/devices", tags=["devices"])


class RegisterDeviceRequest(BaseModel):
    device_id: str = Field(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    claim: bool = False


@router.post("/register")
def register_device(request: RegisterDeviceRequest) -> dict[str, object]:
    """Registers the app install under the account and says whether it may
    stay signed in (the plan limits how many devices can)."""
    container = get_container()
    user = container.auth_provider.get_current_user()
    result = container.register_device_service().execute(
        RegisterDeviceInput(
            owner_id=user.id,
            owner_email=user.email,
            device_id=request.device_id,
            claim=request.claim,
        )
    )
    return result.model_dump()
