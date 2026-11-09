from datetime import date, datetime
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

    def list_all(self) -> list[AccountAge]:
        """Every declaration (the team's review of closed accounts reads these)."""
        ...

    def replace_birth_date(self, owner_id: str, birth_date: date) -> AccountAge | None:
        """Support's correction of a mistyped date; clears a pending correction request."""
        ...

    def set_correction_requested(self, owner_id: str, at: datetime | None) -> AccountAge | None: ...

    def list_declared_before(self, cutoff: datetime) -> list[AccountAge]:
        """Declarations made before [cutoff] (for the 30-day review)."""
        ...
