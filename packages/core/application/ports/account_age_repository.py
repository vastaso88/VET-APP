from datetime import datetime
from typing import Protocol

from packages.core.domain.age.models import AccountAge


class AccountAgeRepository(Protocol):
    def get(self, owner_id: str) -> AccountAge | None: ...

    def create(self, age: AccountAge) -> bool:
        """Stores the declaration only if the owner has none yet. False when
        one exists already: a declared date is never overwritten."""
        ...

    def mark_guardian_ok(self, owner_id: str, at: datetime) -> AccountAge | None:
        """Records the parent-authorisation confirmation; None without a declaration."""
        ...

    def list_declared_before(self, cutoff: datetime) -> list[AccountAge]:
        """Declarations made before [cutoff] (for the 30-day review)."""
        ...
