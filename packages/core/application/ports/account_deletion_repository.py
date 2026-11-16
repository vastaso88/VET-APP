from datetime import datetime
from typing import Protocol

from packages.core.domain.account_deletion.models import AccountDeletionRequest


class AccountDeletionRepository(Protocol):
    def get(self, owner_id: str) -> AccountDeletionRequest | None: ...

    def create(self, request: AccountDeletionRequest) -> bool:
        """Stores the request unless the owner already has one (False then:
        asking twice does not move the date)."""
        ...

    def delete(self, owner_id: str) -> bool:
        """Removes the request (the owner cancelled, or the erase is done)."""
        ...

    def list_due(self, now: datetime) -> list[AccountDeletionRequest]:
        """Requests whose period has ended."""
        ...

    def pending_owner_ids(self) -> set[str]:
        """Everyone whose account is waiting to be erased (their ads are hidden)."""
        ...
