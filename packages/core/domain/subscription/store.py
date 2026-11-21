"""Store subscriptions (Apple App Store, Google Play): the only source of a paid plan.

A paid plan is granted only by a row verified server-side with the store's own
API or by a store-signed notification. What the app says about a payment is
never trusted. The 14-day app trial (models.py) is separate and untouched.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta
from enum import StrEnum

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import SubscriptionPlan


class Store(StrEnum):
    APPLE = "apple"
    GOOGLE = "google"
    # Team-only grants for testing (admin route, never in production).
    ADMIN_TEST = "admin_test"


class BillingPeriod(StrEnum):
    MONTHLY = "monthly"
    YEARLY = "yearly"


class StoreState(StrEnum):
    """Normalised state of one store subscription."""

    PENDING = "pending"  # payment not completed (Google pending / Ask to Buy)
    ACTIVE = "active"  # paid, renews
    CANCELED = "canceled"  # auto-renew off, still paid until expires_at
    IN_GRACE_PERIOD = "in_grace_period"  # payment failing, store keeps access
    BILLING_RETRY = "billing_retry"  # payment failing, no access (Apple retry)
    ON_HOLD = "on_hold"  # Google account hold, no access
    PAUSED = "paused"  # Google pause, no access
    EXPIRED = "expired"
    REVOKED = "revoked"  # Family Sharing revoked / store revoked
    REFUNDED = "refunded"
    REPLACED = "replaced"  # superseded by an upgrade/downgrade (Google linked token)


ACCESS_STATES = frozenset({StoreState.ACTIVE, StoreState.CANCELED, StoreState.IN_GRACE_PERIOD})
PLAN_RANK = {SubscriptionPlan.PLUS: 1, SubscriptionPlan.PRO: 2, SubscriptionPlan.ULTRA: 3}


class CatalogProduct(BaseModel):
    plan: str
    period: BillingPeriod
    apple_product_id: str
    google_product_id: str
    google_base_plan_id: str


def _default_catalog() -> list[CatalogProduct]:
    products: list[CatalogProduct] = []
    for plan in (SubscriptionPlan.PLUS, SubscriptionPlan.PRO, SubscriptionPlan.ULTRA):
        for period in BillingPeriod:
            products.append(
                CatalogProduct(
                    plan=plan,
                    period=period,
                    apple_product_id=f"net.quokkapet.{plan}.{period}",
                    google_product_id=f"quokka_{plan}",
                    google_base_plan_id=period.value,
                )
            )
    return products


class ProductCatalog(BaseModel):
    """Single place that maps store product ids to plan + period. Override with
    the BILLING_CATALOG_JSON environment variable (a JSON list of
    CatalogProduct) without touching the logic."""

    products: list[CatalogProduct] = Field(default_factory=_default_catalog)

    @classmethod
    def from_json(cls, raw: str) -> ProductCatalog:
        if not raw.strip():
            return cls()
        return cls(products=[CatalogProduct.model_validate(p) for p in json.loads(raw)])

    def for_apple(self, product_id: str) -> CatalogProduct | None:
        return next((p for p in self.products if p.apple_product_id == product_id), None)

    def for_google(self, product_id: str, base_plan_id: str | None) -> CatalogProduct | None:
        return next(
            (
                p
                for p in self.products
                if p.google_product_id == product_id
                and (base_plan_id is None or p.google_base_plan_id == base_plan_id)
            ),
            None,
        )


class VerifiedStorePurchase(BaseModel):
    """What the store itself says (API answer or signed payload)."""

    store: Store
    store_subscription_id: str  # Apple originalTransactionId / Google purchase token
    latest_transaction_id: str | None = None  # Apple transactionId / Google orderId
    product_id: str
    base_plan_id: str | None = None
    state: StoreState
    expires_at: datetime | None = None
    auto_renew: bool = False
    grace_expires_at: datetime | None = None
    revoked_at: datetime | None = None
    environment: str = "production"  # production | sandbox
    account_token: str | None = None  # appAccountToken / obfuscatedExternalAccountId
    linked_previous_id: str | None = None  # Google linkedPurchaseToken
    needs_acknowledgement: bool = False
    event_time: datetime = Field(default_factory=utc_now)


class StoreEntitlement(BaseModel):
    """One store subscription bound to exactly one Quokka account."""

    owner_id: str
    store: Store
    store_subscription_id: str
    latest_transaction_id: str | None = None
    product_id: str
    plan: str
    period: BillingPeriod
    state: StoreState
    expires_at: datetime | None = None
    auto_renew: bool = False
    grace_expires_at: datetime | None = None
    revoked_at: datetime | None = None
    environment: str = "production"
    last_event_at: datetime = Field(default_factory=utc_now)
    last_verified_at: datetime = Field(default_factory=utc_now)
    # Set when a reconciliation with the store failed; cleared on success.
    verification_error_at: datetime | None = None
    anomaly: str | None = None
    created_at: datetime = Field(default_factory=utc_now)

    def grants_access(self, *, now: datetime | None = None, tolerance: timedelta) -> bool:
        """Access from the last verified state only. [tolerance] is applied
        solely when the last re-check with the store failed (temporary store
        or network error) on a subscription that was renewing: it keeps an
        existing right for a bounded time, it never creates a new one."""
        moment = now or utc_now()
        if self.state not in ACCESS_STATES:
            return False
        end = self.expires_at
        if self.state == StoreState.IN_GRACE_PERIOD and self.grace_expires_at is not None:
            end = max(end or self.grace_expires_at, self.grace_expires_at)
        if end is None:
            return False
        if moment < end:
            return True
        return (
            self.verification_error_at is not None
            and self.state == StoreState.ACTIVE
            and self.auto_renew
            and moment < end + tolerance
        )


def best_plan(
    entitlements: list[StoreEntitlement], *, tolerance: timedelta, now: datetime | None = None
) -> StoreEntitlement | None:
    active = [e for e in entitlements if e.grants_access(now=now, tolerance=tolerance)]
    if not active:
        return None
    return max(active, key=lambda e: (PLAN_RANK.get(e.plan, 0), e.expires_at or utc_now()))
