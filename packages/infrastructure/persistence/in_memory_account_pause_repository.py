from datetime import datetime

from packages.core.application.ports.account_pause_repository import AccountPauseRepository
from packages.core.domain.account_pause.models import AccountPause


class InMemoryAccountPauseRepository(AccountPauseRepository):
    """Local development and tests."""

    def __init__(self) -> None:
        self._items: dict[str, AccountPause] = {}

    def get(self, owner_id: str) -> AccountPause | None:
        return self._items.get(owner_id)

    def is_paused(self, owner_id: str) -> bool:
        pause = self._items.get(owner_id)
        return pause is not None and pause.active

    def paused_owner_ids(self) -> frozenset[str]:
        return frozenset(owner for owner, pause in self._items.items() if pause.active)

    def create(self, pause: AccountPause) -> bool:
        current = self._items.get(pause.owner_id)
        if current is not None and current.active:
            return False
        self._items[pause.owner_id] = pause
        return True

    def resume(self, owner_id: str, at: datetime) -> None:
        current = self._items.get(owner_id)
        if current is not None and current.active:
            self._items[owner_id] = current.model_copy(update={"resumed_at": at})

    def acknowledge(self, owner_id: str) -> bool:
        current = self._items.get(owner_id)
        if current is None or current.active:
            return False
        del self._items[owner_id]
        return True

    def delete(self, owner_id: str) -> bool:
        return self._items.pop(owner_id, None) is not None

    def record_notice(self, owner_id: str, notice: str, at: datetime) -> None:
        current = self._items.get(owner_id)
        if current is not None and current.active:
            self._items[owner_id] = current.model_copy(
                update={"last_notice": notice, "last_notice_at": at}
            )

    def list_all(self) -> list[AccountPause]:
        return [pause for pause in self._items.values() if pause.active]
