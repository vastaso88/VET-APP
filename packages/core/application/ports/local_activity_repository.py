from typing import Protocol

from packages.core.domain.local_activity.models import LocalActivity


class LocalActivityRepository(Protocol):
    def save(self, activity: LocalActivity) -> LocalActivity: ...

    def list_active(self) -> list[LocalActivity]: ...
