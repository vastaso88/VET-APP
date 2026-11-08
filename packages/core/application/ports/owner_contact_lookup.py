from dataclasses import dataclass
from datetime import date
from typing import Protocol


@dataclass(frozen=True)
class OwnerContact:
    """How an account can be reached. Read-only and never logged or returned
    to a client: callers use it to decide, not to display."""

    email: str | None
    email_confirmed: bool
    # The date of birth the owner declared at registration, if any. None =
    # not declared (today no screen records it), which callers treat as "not
    # known to be an adult".
    birth_date: date | None = None


class OwnerContactLookup(Protocol):
    def get(self, owner_id: str) -> OwnerContact | None:
        """None when the account cannot be found or the lookup failed."""
        ...
