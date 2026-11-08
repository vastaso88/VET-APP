from datetime import datetime

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.domain.age.models import AccountAge


class InMemoryAccountAgeRepository(AccountAgeRepository):
    """Local development and tests."""

    def __init__(self) -> None:
        self._items: dict[str, AccountAge] = {}

    def get(self, owner_id: str) -> AccountAge | None:
        return self._items.get(owner_id)

    def create(self, age: AccountAge) -> bool:
        if age.owner_id in self._items:
            return False
        self._items[age.owner_id] = age
        return True

    def mark_guardian_ok(self, owner_id: str, at: datetime) -> AccountAge | None:
        current = self._items.get(owner_id)
        if current is None:
            return None
        updated = current.model_copy(update={"guardian_ok_at": at})
        self._items[owner_id] = updated
        return updated

    def list_declared_before(self, cutoff: datetime) -> list[AccountAge]:
        return [item for item in self._items.values() if item.declared_at < cutoff]
