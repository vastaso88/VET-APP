from datetime import datetime
from typing import Protocol

from packages.core.domain.subscription.models import Subscription


class SubscriptionRepository(Protocol):
    def get(self, owner_id: str) -> Subscription | None: ...

    def save(self, subscription: Subscription) -> Subscription: ...

    def set_access_lost_at(self, owner_id: str, value: datetime | None) -> None:
        """Starts (or, with None, stops) the retention clock of one account.
        A column of its own, so `save` never touches it and a database that
        does not have it yet keeps working for everything else."""
        ...

    def list_without_plan(self) -> list[Subscription]:
        """Every subscription with no current plan (trial running or over)."""
        ...
