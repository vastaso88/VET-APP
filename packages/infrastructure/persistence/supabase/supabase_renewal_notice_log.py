"""The reminders of the yearly renewals, on the tables of the store subscriptions
(scripts/setup/store_billing.sql): no table and no column of its own."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from packages.core.application.ports.renewal_notice_log import RenewalNoticeLog
from packages.core.domain.subscription.renewal_notice import EVENT_TYPE
from packages.core.domain.subscription.store import StoreEntitlement
from packages.infrastructure.persistence.supabase.supabase_store_billing import _FIELDS

if TYPE_CHECKING:
    from supabase import Client


class SupabaseRenewalNoticeLog(RenewalNoticeLog):
    def __init__(self, client: Client) -> None:
        self._client = client

    def yearly_renewing_between(self, start: datetime, end: datetime) -> list[StoreEntitlement]:
        response = (
            self._client.table("store_subscriptions")
            .select(_FIELDS)
            .eq("period", "yearly")
            .eq("state", "active")
            .gte("expires_at", start.isoformat())
            .lt("expires_at", end.isoformat())
            .limit(1000)
            .execute()
        )
        rows = [StoreEntitlement.model_validate(row) for row in (response.data or [])]
        return [row for row in rows if row.auto_renew]

    def booked_since(self, store: str, store_subscription_id: str, since: datetime) -> bool:
        response = (
            self._client.table("store_events")
            .select("event_id")
            .eq("store", str(store))
            .eq("notification_type", EVENT_TYPE)
            .eq("store_subscription_id", store_subscription_id)
            .gte("signed_at", since.isoformat())
            .limit(1)
            .execute()
        )
        return bool(response.data)

    def release(self, store: str, event_id: str, owner_id: str) -> None:
        (
            self._client.table("store_events")
            .delete()
            .eq("store", str(store))
            .eq("event_id", event_id)
            .eq("owner_id", owner_id)
            .eq("notification_type", EVENT_TYPE)
            .execute()
        )
