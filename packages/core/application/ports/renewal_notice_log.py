from datetime import datetime
from typing import Protocol

from packages.core.domain.subscription.store import StoreEntitlement


class RenewalNoticeLog(Protocol):
    """Which yearly renewals are coming and which reminders are already booked. The register is
    the one of the store events (one row per event, inserted once, erased with the account):
    the booking itself is `StoreEntitlementRepository.record_event`."""

    def yearly_renewing_between(self, start: datetime, end: datetime) -> list[StoreEntitlement]:
        """Yearly subscriptions, active and renewing, that expire in [start, end)."""
        ...

    def booked_since(self, store: str, store_subscription_id: str, since: datetime) -> bool:
        """Whether a reminder about this subscription was booked after [since]."""
        ...

    def release(self, store: str, event_id: str, owner_id: str) -> None:
        """Gives back a booking whose message certainly did not go."""
        ...
