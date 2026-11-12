from pydantic import BaseModel, Field

from packages.core.application.ports.owner_limits import OwnerLimitsLookup
from packages.core.application.ports.user_device_repository import UserDeviceRepository
from packages.core.domain.common.entity import utc_now
from packages.core.domain.device.models import UserDevice


class RegisterDeviceInput(BaseModel):
    owner_id: str
    owner_email: str | None = None
    device_id: str = Field(min_length=8, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")
    # True right after a sign-in: this device takes a place even if it had
    # been revoked. False on an ordinary start of the app.
    claim: bool = False


class RegisterDeviceOutput(BaseModel):
    # False: a newer device took this one's place; the app signs out.
    active: bool
    # The plan's limit, None when the account has none.
    max_devices: int | None = None


class RegisterDeviceService:
    """Keeps the number of devices signed in to one account within the
    plan's limit (`PlanLimits.max_devices`). When a device signs in and the
    places are full, the one seen least recently is revoked: it finds out
    the next time it opens the app."""

    def __init__(
        self, repository: UserDeviceRepository, owner_limits: OwnerLimitsLookup | None = None
    ) -> None:
        self._repository = repository
        self._owner_limits = owner_limits

    def execute(self, data: RegisterDeviceInput) -> RegisterDeviceOutput:
        now = utc_now()
        limits = self._owner_limits(data.owner_id, data.owner_email) if self._owner_limits else None
        max_devices = limits.max_devices if limits is not None else None

        devices = self._repository.list_for_owner(data.owner_id)
        mine = next((d for d in devices if d.device_id == data.device_id), None)

        if mine is not None and mine.is_active:
            self._repository.save(mine.model_copy(update={"last_seen_at": now}))
            return RegisterDeviceOutput(active=True, max_devices=max_devices)
        if mine is not None and not data.claim:
            return RegisterDeviceOutput(active=False, max_devices=max_devices)

        # A new device, or a revoked one signing in again: it needs a place.
        if max_devices is not None:
            others = [d for d in devices if d.is_active and d.device_id != data.device_id]
            overflow = len(others) - max(0, max_devices - 1)
            for oldest in sorted(others, key=lambda d: d.last_seen_at)[: max(0, overflow)]:
                self._repository.save(oldest.model_copy(update={"revoked_at": now}))

        self._repository.save(
            UserDevice(
                owner_id=data.owner_id,
                device_id=data.device_id,
                first_seen_at=mine.first_seen_at if mine is not None else now,
                last_seen_at=now,
            )
        )
        return RegisterDeviceOutput(active=True, max_devices=max_devices)
