from datetime import datetime
from typing import Protocol

from packages.core.domain.account_pause.models import AccountPause


class AccountPauseRepository(Protocol):
    def get(self, owner_id: str) -> AccountPause | None:
        """The row in any state: active, or ended and not yet acknowledged."""
        ...

    def is_paused(self, owner_id: str) -> bool:
        """True only while the pause is active (not ended)."""
        ...

    def paused_owner_ids(self) -> frozenset[str]:
        """Everyone whose account is paused (in bulk, for the scheduled jobs:
        the 120-day sequence leaves them out, their ads are hidden)."""
        ...

    def create(self, pause: AccountPause) -> bool:
        """Stores the pause unless the owner already has an active one (False then:
        asking twice does not move the date). An ended one that was never
        acknowledged is replaced."""
        ...

    def resume(self, owner_id: str, at: datetime) -> None:
        """The owner signed in again: the pause is over. The row stays, marked,
        so the app can say so once."""
        ...

    def acknowledge(self, owner_id: str) -> bool:
        """The app showed that the pause is over: the ended row goes."""
        ...

    def delete(self, owner_id: str) -> bool:
        """Removes the row in any state (the account is erased)."""
        ...

    def record_notice(self, owner_id: str, notice: str, at: datetime) -> None: ...

    def list_all(self) -> list[AccountPause]:
        """The ACTIVE pauses."""
        ...
