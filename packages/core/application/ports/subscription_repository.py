from typing import Protocol

from packages.core.domain.subscription.models import Subscription


class SubscriptionRepository(Protocol):
    def get(self, owner_id: str) -> Subscription | None: ...

    def save(self, subscription: Subscription) -> Subscription: ...
