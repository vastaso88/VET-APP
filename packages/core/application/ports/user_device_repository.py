from typing import Protocol

from packages.core.domain.device.models import UserDevice


class UserDeviceRepository(Protocol):
    def list_for_owner(self, owner_id: str) -> list[UserDevice]: ...

    def save(self, device: UserDevice) -> UserDevice: ...
