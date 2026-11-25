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

    def list_pending(self) -> list[AccountDeletionRequest]:
        """Every request still waiting (for the e-mail notices)."""
        ...

    def notice_log_available(self) -> bool:
        """True when the column that remembers the last notice exists. Checked before
        the first e-mail of a run: without it the same notice would go out every run."""
        ...

    def claim_notice(self, owner_id: str, notice: str, previous: str | None, at: datetime) -> bool:
        """Books [notice] BEFORE it is sent: a conditional update that succeeds only while
        last_notice is still [previous] (what the caller read). True = the booking is
        this caller's; False = someone else booked it first or the request is gone, so
        nothing is sent. This is what stops two runs writing the same notice."""
        ...

    def release_notice(
        self,
        owner_id: str,
        notice: str,
        previous: str | None,
        previous_at: datetime | None,
    ) -> None:
        """Gives the booking back (last_notice and its time become [previous] and
        [previous_at] again), only while it still says [notice]. Used when the message
        certainly did not go."""
        ...

    def pending_owner_ids(self) -> set[str]:
        """Everyone whose account is waiting to be erased (their ads are hidden)."""
        ...
