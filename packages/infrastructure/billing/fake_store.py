"""Local/test double of a store verifier: no network, no real purchase."""

from __future__ import annotations

from packages.core.application.ports.store_billing import (
    StoreRejectedError,
    StoreTemporaryError,
)
from packages.core.domain.subscription.store import VerifiedStorePurchase


class FakeStore:
    """What the store would answer for each id; `down` simulates an outage."""

    def __init__(self) -> None:
        self.answers: dict[str, VerifiedStorePurchase] = {}
        self.down = False
        self.acknowledged: list[str] = []

    def verify(
        self, *, store_subscription_id: str, product_id: str | None = None
    ) -> VerifiedStorePurchase:
        if self.down:
            raise StoreTemporaryError("down")
        try:
            return self.answers[store_subscription_id]
        except KeyError as exc:
            raise StoreRejectedError("unknown") from exc

    def acknowledge(self, purchase: VerifiedStorePurchase) -> None:
        self.acknowledged.append(purchase.store_subscription_id)
