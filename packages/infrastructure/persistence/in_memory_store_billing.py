from datetime import datetime

from packages.core.application.ports.store_billing import StoreEntitlementRepository
from packages.core.domain.subscription.store import StoreEntitlement


class InMemoryStoreEntitlementRepository(StoreEntitlementRepository):
    def __init__(self) -> None:
        self._items: dict[tuple[str, str], StoreEntitlement] = {}
        self.events: dict[str, dict[str, object]] = {}
        self._tokens: dict[str, str] = {}

    def get(self, store: str, store_subscription_id: str) -> StoreEntitlement | None:
        return self._items.get((str(store), store_subscription_id))

    def list_for_owner(self, owner_id: str) -> list[StoreEntitlement]:
        return [e for e in self._items.values() if e.owner_id == owner_id]

    def save(self, entitlement: StoreEntitlement) -> StoreEntitlement:
        key = (str(entitlement.store), entitlement.store_subscription_id)
        stored = self._items.get(key)
        if stored is not None and stored.owner_id != entitlement.owner_id:
            # Mirrors the unique (store, store_subscription_id) constraint.
            raise ValueError("store subscription already bound to another account")
        self._items[key] = entitlement
        return entitlement

    def list_due_for_reconciliation(self, verified_before: datetime) -> list[StoreEntitlement]:
        return [e for e in self._items.values() if e.last_verified_at < verified_before]

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
        key = f"{store}:{event_id}"
        if key in self.events:
            return False
        self.events[key] = {
            "type": notification_type,
            "owner_id": owner_id,
            "store_subscription_id": store_subscription_id,
            "signed_at": signed_at,
            "outcome": outcome,
        }
        return True

    def save_account_token(self, owner_id: str, token: str) -> None:
        self._tokens[token] = owner_id

    def owner_for_account_token(self, token: str) -> str | None:
        return self._tokens.get(token)

    def list_all(self) -> list[StoreEntitlement]:
        return list(self._items.values())
