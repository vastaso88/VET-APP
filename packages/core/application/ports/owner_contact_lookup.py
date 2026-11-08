from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class OwnerContact:
    """How an account can be reached. Read-only and never logged or returned
    to a client: callers use it to decide, not to display."""

    email: str | None
    email_confirmed: bool


class OwnerContactLookup(Protocol):
    def get(self, owner_id: str) -> OwnerContact | None:
        """None when the account cannot be found or the lookup failed."""
        ...
