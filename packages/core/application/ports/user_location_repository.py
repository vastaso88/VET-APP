from typing import Protocol

from packages.core.domain.geo.models import UserLocation


class UserLocationRepository(Protocol):
    def get(self, owner_id: str) -> UserLocation | None: ...

    def save(self, user_location: UserLocation) -> UserLocation: ...
