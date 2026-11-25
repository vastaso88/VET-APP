from datetime import datetime

from packages.core.application.ports.renewal_notice_log import RenewalNoticeLog
from packages.core.domain.subscription.renewal_notice import EVENT_TYPE
from packages.core.domain.subscription.store import BillingPeriod, StoreEntitlement, StoreState
from packages.infrastructure.persistence.in_memory_store_billing import (
    InMemoryStoreEntitlementRepository,
)


class InMemoryRenewalNoticeLog(RenewalNoticeLog):
    """Local/test double over the same in-memory rows as the store subscriptions."""

    def __init__(self, entitlements: InMemoryStoreEntitlementRepository) -> None:
        self._entitlements = entitlements

    def yearly_renewing_between(self, start: datetime, end: datetime) -> list[StoreEntitlement]:
        return [
            e
            for e in self._entitlements.list_all()
            if e.period == BillingPeriod.YEARLY
            and e.state == StoreState.ACTIVE
            and e.auto_renew
            and e.expires_at is not None
            and start <= e.expires_at < end
        ]

    def booked_since(self, store: str, store_subscription_id: str, since: datetime) -> bool:
        return any(
            key.startswith(f"{store}:")
            and event["type"] == EVENT_TYPE
            and event["store_subscription_id"] == store_subscription_id
            and isinstance(event["signed_at"], datetime)
            and event["signed_at"] >= since
            for key, event in self._entitlements.events.items()
        )

    def release(self, store: str, event_id: str, owner_id: str) -> None:
        key = f"{store}:{event_id}"
        event = self._entitlements.events.get(key)
        if event is not None and event["owner_id"] == owner_id and event["type"] == EVENT_TYPE:
            del self._entitlements.events[key]
