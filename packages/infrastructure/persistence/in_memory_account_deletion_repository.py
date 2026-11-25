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

    def list_pending(self) -> list[AccountDeletionRequest]:
        return list(self._items.values())

    def notice_log_available(self) -> bool:
        return True

    def claim_notice(self, owner_id: str, notice: str, previous: str | None, at: datetime) -> bool:
        current = self._items.get(owner_id)
        if current is None or current.last_notice != previous:
            return False
        self._items[owner_id] = current.model_copy(
            update={"last_notice": notice, "last_notice_at": at}
        )
        return True

    def release_notice(
        self,
        owner_id: str,
        notice: str,
        previous: str | None,
        previous_at: datetime | None,
    ) -> None:
        current = self._items.get(owner_id)
        if current is not None and current.last_notice == notice:
            self._items[owner_id] = current.model_copy(
                update={"last_notice": previous, "last_notice_at": previous_at}
            )

    def pending_owner_ids(self) -> set[str]:
        return set(self._items)
