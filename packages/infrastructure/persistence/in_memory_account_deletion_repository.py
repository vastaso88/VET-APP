from datetime import datetime

from packages.core.application.ports.account_deletion_repository import (
    AccountDeletionRepository,
)
from packages.core.domain.account_deletion.models import AccountDeletionRequest


class InMemoryAccountDeletionRepository(AccountDeletionRepository):
    """Local development and tests."""

    def __init__(self) -> None:
        self._items: dict[str, AccountDeletionRequest] = {}

    def get(self, owner_id: str) -> AccountDeletionRequest | None:
        return self._items.get(owner_id)

    def create(self, request: AccountDeletionRequest) -> bool:
        if request.owner_id in self._items:
            return False
        self._items[request.owner_id] = request
        return True

    def delete(self, owner_id: str) -> bool:
        return self._items.pop(owner_id, None) is not None

    def list_due(self, now: datetime) -> list[AccountDeletionRequest]:
        return [item for item in self._items.values() if item.purge_after <= now]

    def pending_owner_ids(self) -> set[str]:
        return set(self._items)
