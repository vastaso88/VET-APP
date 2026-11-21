from datetime import datetime
from typing import Protocol

from pydantic import BaseModel

from packages.core.domain.subscription.store import (
    StoreEntitlement,
    VerifiedStorePurchase,
)


class StoreTemporaryError(Exception):
    """The store could not be reached or answered 5xx/429: retry later."""


class StoreRejectedError(Exception):
    """The store says the purchase/notification is not genuine or unknown."""


class StoreNotification(BaseModel):
    """A notification whose signature/sender has already been verified."""

    event_id: str  # Apple notificationUUID / Pub/Sub messageId
    store: str
    notification_type: str
    subtype: str | None = None
    signed_at: datetime
    store_subscription_id: str | None = None
    # Apple carries the signed state; Google only the token (refetch).
    purchase: VerifiedStorePurchase | None = None
    refund: bool = False
    revoke: bool = False
    environment: str = "production"


class StoreEntitlementRepository(Protocol):
    def get(self, store: str, store_subscription_id: str) -> StoreEntitlement | None: ...

    def list_for_owner(self, owner_id: str) -> list[StoreEntitlement]: ...

    def save(self, entitlement: StoreEntitlement) -> StoreEntitlement: ...

    def list_due_for_reconciliation(self, verified_before: datetime) -> list[StoreEntitlement]: ...

    def record_event(
        self,
        *,
        event_id: str,
        store: str,
        notification_type: str,
        owner_id: str | None,
        store_subscription_id: str | None,
        signed_at: datetime,
        outcome: str,
    ) -> bool:
        """Stores the event once. False if [event_id] was already recorded
        (duplicate delivery): the caller then does nothing."""
        ...

    def save_account_token(self, owner_id: str, token: str) -> None: ...

    def owner_for_account_token(self, token: str) -> str | None: ...

    def list_all(self) -> list[StoreEntitlement]: ...


class StoreVerifier(Protocol):
    def verify(
        self, *, store_subscription_id: str, product_id: str | None = None
    ) -> VerifiedStorePurchase:
        """Asks the store for the current state of one subscription.
        Apple: any transaction id; Google: purchase token (+ product id)."""
        ...

    def acknowledge(self, purchase: VerifiedStorePurchase) -> None: ...
