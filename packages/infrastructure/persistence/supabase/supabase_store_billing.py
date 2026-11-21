"""Store subscriptions in Supabase (supabase/migrations/20261121180000_store_billing.sql).
Written only by the backend (service_role); owners can read their own rows."""

from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING, Any

from packages.core.application.ports.store_billing import StoreEntitlementRepository
from packages.core.domain.subscription.store import StoreEntitlement

if TYPE_CHECKING:
    from supabase import Client

_FIELDS = (
    "owner_id,store,store_subscription_id,latest_transaction_id,product_id,plan,period,state,"
    "expires_at,auto_renew,grace_expires_at,revoked_at,environment,last_event_at,"
    "last_verified_at,verification_error_at,anomaly,created_at"
)


class SupabaseStoreEntitlementRepository(StoreEntitlementRepository):
    def __init__(self, client: Client) -> None:
        self._client = client

    def _rows(self, response: Any) -> list[StoreEntitlement]:
        return [StoreEntitlement.model_validate(r) for r in (response.data or [])]

    def get(self, store: str, store_subscription_id: str) -> StoreEntitlement | None:
        rows = self._rows(
            self._client.table("store_subscriptions")
            .select(_FIELDS)
            .eq("store", str(store))
            .eq("store_subscription_id", store_subscription_id)
            .limit(1)
            .execute()
        )
        return rows[0] if rows else None

    def list_for_owner(self, owner_id: str) -> list[StoreEntitlement]:
        return self._rows(
            self._client.table("store_subscriptions")
            .select(_FIELDS)
            .eq("owner_id", owner_id)
            .execute()
        )

    def save(self, entitlement: StoreEntitlement) -> StoreEntitlement:
        payload = entitlement.model_dump(mode="json")
        # The unique (store, store_subscription_id) index refuses a second
        # owner; the update is restricted to the same owner on purpose.
        existing = self.get(entitlement.store, entitlement.store_subscription_id)
        if existing is None:
            self._client.table("store_subscriptions").insert(payload).execute()
        elif existing.owner_id != entitlement.owner_id:
            raise ValueError("store subscription already bound to another account")
        else:
            payload.pop("created_at", None)
            (
                self._client.table("store_subscriptions")
                .update(payload)
                .eq("store", str(entitlement.store))
                .eq("store_subscription_id", entitlement.store_subscription_id)
                .eq("owner_id", entitlement.owner_id)
                .execute()
            )
        return entitlement

    def list_due_for_reconciliation(self, verified_before: datetime) -> list[StoreEntitlement]:
        return self._rows(
            self._client.table("store_subscriptions")
            .select(_FIELDS)
            .lt("last_verified_at", verified_before.isoformat())
            .in_(
                "state",
                [
                    "active",
                    "canceled",
                    "in_grace_period",
                    "billing_retry",
                    "on_hold",
                    "paused",
                    "pending",
                ],
            )
            .limit(500)
            .execute()
        )

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
        response = (
            self._client.table("store_events")
            .upsert(
                {
                    "store": store,
                    "event_id": event_id,
                    "notification_type": notification_type[:120],
                    "owner_id": owner_id,
                    "store_subscription_id": store_subscription_id,
                    "signed_at": signed_at.isoformat(),
                    "outcome": outcome,
                },
                on_conflict="store,event_id",
                ignore_duplicates=True,
            )
            .execute()
        )
        return bool(response.data)

    def save_account_token(self, owner_id: str, token: str) -> None:
        self._client.table("store_account_tokens").upsert(
            {"owner_id": owner_id, "account_token": token},
            on_conflict="owner_id",
            ignore_duplicates=True,
        ).execute()

    def owner_for_account_token(self, token: str) -> str | None:
        response = (
            self._client.table("store_account_tokens")
            .select("owner_id")
            .eq("account_token", token)
            .limit(1)
            .execute()
        )
        rows: list[Any] = list(response.data or [])
        return str(rows[0]["owner_id"]) if rows else None

    def list_all(self) -> list[StoreEntitlement]:
        return self._rows(
            self._client.table("store_subscriptions").select(_FIELDS).limit(5000).execute()
        )
