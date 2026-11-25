"""Server-side verification of App Store / Google Play subscriptions.

Rules (docs/billing/01_architettura_abbonamenti.md):
- a right comes only from the store's API or a store-signed notification;
- one store subscription belongs to one account: the account token sent at
  purchase time must match, a subscription already bound to someone else is
  refused (no silent transfer);
- every notification is recorded once (idempotent) and never moves a
  subscription back in time (out-of-order delivery);
- a temporary store error keeps the last verified state, with the bounded
  tolerance of StoreEntitlement.grants_access, and never grants anything new.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import uuid
from datetime import timedelta

from pydantic import BaseModel

from packages.core.application.ports.store_billing import (
    StoreEntitlementRepository,
    StoreNotification,
    StoreRejectedError,
    StoreTemporaryError,
    StoreVerifier,
)
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.store import (
    CatalogProduct,
    ProductCatalog,
    Store,
    StoreEntitlement,
    StoreState,
    VerifiedStorePurchase,
    best_plan,
)
from packages.shared.auth_context import forget_request_subscription

logger = logging.getLogger(__name__)


class PurchaseOwnershipError(Exception):
    """The purchase belongs to another account, or carries no/the wrong token."""

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class UnknownProductError(Exception):
    pass


class VerifyPurchaseOutput(BaseModel):
    entitlement: StoreEntitlement
    plan: str | None
    # The client may call completePurchase/finishTransaction only when True.
    complete_transaction: bool


class StoreBillingService:
    def __init__(
        self,
        *,
        entitlements: StoreEntitlementRepository,
        subscriptions: SubscriptionRepository,
        verifiers: dict[Store, StoreVerifier],
        catalog: ProductCatalog,
        account_token_secret: str,
        verification_tolerance: timedelta = timedelta(hours=24),
        allowed_environments: frozenset[str] = frozenset({"production"}),
    ) -> None:
        if not account_token_secret:
            raise ValueError("BILLING_ACCOUNT_TOKEN_SECRET is required for store billing")
        self._entitlements = entitlements
        self._subscriptions = subscriptions
        self._verifiers = verifiers
        self._catalog = catalog
        self._secret = account_token_secret.encode()
        self.tolerance = verification_tolerance
        self._environments = allowed_environments

    # --- identity --------------------------------------------------------

    def account_token(self, owner_id: str) -> str:
        """Pseudonymous UUID passed to the store at purchase time
        (appAccountToken / obfuscatedAccountId). Never the Supabase id."""
        digest = hmac.new(self._secret, f"quokka-billing:{owner_id}".encode(), hashlib.sha256)
        token = str(uuid.UUID(bytes=digest.digest()[:16], version=4))
        self._entitlements.save_account_token(owner_id, token)
        return token

    # --- client-initiated verification ------------------------------------

    def verify_purchase(
        self, *, owner_id: str, store: Store, store_subscription_id: str, product_id: str | None
    ) -> VerifyPurchaseOutput:
        verifier = self._verifier(store)
        purchase = verifier.verify(
            store_subscription_id=store_subscription_id, product_id=product_id
        )
        self._check_environment(purchase)
        expected = self.account_token(owner_id)
        if purchase.account_token is None:
            raise PurchaseOwnershipError("purchase_account_token_missing")
        if not hmac.compare_digest(purchase.account_token, expected):
            raise PurchaseOwnershipError("purchase_owned_by_another_account")
        existing = self._entitlements.get(store, purchase.store_subscription_id)
        if existing is not None and existing.owner_id != owner_id:
            self._flag(existing, "claim_attempt_by_another_account")
            raise PurchaseOwnershipError("purchase_owned_by_another_account")
        entitlement = self._apply(owner_id, purchase, existing)
        complete = purchase.state != StoreState.PENDING
        if complete and purchase.needs_acknowledgement:
            verifier.acknowledge(purchase)
        return VerifyPurchaseOutput(
            entitlement=entitlement, plan=self.sync_plan(owner_id), complete_transaction=complete
        )

    def restore(self, *, owner_id: str, store: Store, ids: list[str]) -> list[VerifyPurchaseOutput]:
        """Restore = verify each id the store gave back to the device. Ids that
        belong to someone else are skipped, never moved."""
        results: list[VerifyPurchaseOutput] = []
        for store_id in ids[:50]:
            try:
                results.append(
                    self.verify_purchase(
                        owner_id=owner_id,
                        store=store,
                        store_subscription_id=store_id,
                        product_id=None,
                    )
                )
            except (PurchaseOwnershipError, StoreRejectedError, UnknownProductError):
                continue
        return results

    # --- notifications ----------------------------------------------------

    def handle_notification(self, notification: StoreNotification) -> str:
        """Returns the outcome; duplicates are detected before any change."""
        store = Store(notification.store)
        purchase = notification.purchase
        store_id = notification.store_subscription_id or (
            purchase.store_subscription_id if purchase else None
        )
        if store_id is None:
            outcome = "ignored_no_subscription"
            self._record(notification, None, store_id, outcome)
            return outcome
        if purchase is None:
            # Google: the notification only says "something changed". The
            # authoritative state comes from the API, so order does not matter.
            # A StoreTemporaryError propagates unrecorded: the store redelivers.
            purchase = self._verifier(store).verify(store_subscription_id=store_id)
        if purchase.environment not in self._environments:
            if self._record(notification, None, store_id, "ignored_environment"):
                return "ignored_environment"
            return "duplicate"
        existing = self._entitlements.get(store, store_id)
        owner_id = existing.owner_id if existing else None
        if owner_id is None and purchase.account_token:
            owner_id = self._entitlements.owner_for_account_token(purchase.account_token)
        if owner_id is None:
            outcome = "unmatched_owner"
        elif (
            existing is not None
            and notification.signed_at < existing.last_event_at
            and (notification.purchase is not None)
        ):
            outcome = "stale_ignored"
        else:
            if notification.refund:
                purchase = purchase.model_copy(
                    update={"state": StoreState.REFUNDED, "revoked_at": notification.signed_at}
                )
            elif notification.revoke:
                purchase = purchase.model_copy(
                    update={"state": StoreState.REVOKED, "revoked_at": notification.signed_at}
                )
            purchase = purchase.model_copy(update={"event_time": notification.signed_at})
            outcome = "applied"
        if not self._record(notification, owner_id, store_id, outcome):
            return "duplicate"
        if outcome == "applied" and owner_id is not None:
            self._apply(owner_id, purchase, existing)
            self.sync_plan(owner_id)
        return outcome

    # --- reconciliation ---------------------------------------------------

    def reconcile(self, *, older_than: timedelta = timedelta(hours=12)) -> dict[str, int]:
        counts = {"checked": 0, "updated": 0, "errors": 0}
        for entitlement in self._entitlements.list_due_for_reconciliation(utc_now() - older_than):
            if entitlement.store == Store.ADMIN_TEST:
                continue
            counts["checked"] += 1
            try:
                purchase = self._verifier(entitlement.store).verify(
                    store_subscription_id=entitlement.store_subscription_id,
                    product_id=entitlement.product_id,
                )
            except StoreTemporaryError:
                counts["errors"] += 1
                if entitlement.verification_error_at is None:
                    self._entitlements.save(
                        entitlement.model_copy(update={"verification_error_at": utc_now()})
                    )
                continue
            except StoreRejectedError:
                counts["errors"] += 1
                self._entitlements.save(
                    entitlement.model_copy(
                        update={"state": StoreState.EXPIRED, "anomaly": "store_rejected_on_recheck"}
                    )
                )
                self.sync_plan(entitlement.owner_id)
                continue
            self._apply(
                entitlement.owner_id,
                purchase.model_copy(
                    update={"event_time": max(utc_now(), entitlement.last_event_at)}
                ),
                entitlement,
            )
            self.sync_plan(entitlement.owner_id)
            counts["updated"] += 1
        return counts

    def store_says(
        self, entitlement: StoreEntitlement
    ) -> tuple[VerifiedStorePurchase, CatalogProduct]:
        """What the store says right now about a subscription already bound to an account, and
        the product of the catalogue it is. Read-only: nothing is saved, no right changes."""
        purchase = self._verifier(entitlement.store).verify(
            store_subscription_id=entitlement.store_subscription_id,
            product_id=entitlement.product_id,
        )
        self._check_environment(purchase)
        return purchase, self._product(purchase)

    # --- plan -------------------------------------------------------------

    def sync_plan(self, owner_id: str) -> str | None:
        """subscriptions.plan mirrors the best verified entitlement, so limits
        and the access gate keep reading one column."""
        best = best_plan(self._entitlements.list_for_owner(owner_id), tolerance=self.tolerance)
        plan = best.plan if best else None
        subscription = self._subscriptions.get(owner_id)
        if subscription is not None and subscription.plan != plan:
            self._subscriptions.save(subscription.model_copy(update={"plan": plan}))
        # The plan (or the entitlements behind it) may have changed during this request.
        forget_request_subscription(owner_id)
        return plan

    def entitlements_for(self, owner_id: str) -> list[StoreEntitlement]:
        return self._entitlements.list_for_owner(owner_id)

    def grant_admin_test(self, owner_id: str, plan: str, days: int) -> StoreEntitlement:
        product = next(p for p in self._catalog.products if p.plan == plan)
        now = utc_now()
        entitlement = StoreEntitlement(
            owner_id=owner_id,
            store=Store.ADMIN_TEST,
            store_subscription_id=f"admin-test-{owner_id}",
            product_id=product.apple_product_id,
            plan=plan,
            period=product.period,
            state=StoreState.ACTIVE,
            expires_at=now + timedelta(days=days),
            environment="test",
            anomaly="admin_test_grant",
        )
        self._entitlements.save(entitlement)
        forget_request_subscription(owner_id)
        self.sync_plan(owner_id)
        return entitlement

    # --- internals ----------------------------------------------------------

    def _verifier(self, store: Store) -> StoreVerifier:
        verifier = self._verifiers.get(store)
        if verifier is None:
            raise StoreTemporaryError(f"{store} verification is not configured")
        return verifier

    def _check_environment(self, purchase: VerifiedStorePurchase) -> None:
        if purchase.environment not in self._environments:
            raise StoreRejectedError(f"environment {purchase.environment} not accepted")

    def _product(self, purchase: VerifiedStorePurchase) -> CatalogProduct:
        product = (
            self._catalog.for_apple(purchase.product_id)
            if purchase.store == Store.APPLE
            else self._catalog.for_google(purchase.product_id, purchase.base_plan_id)
        )
        if product is None:
            raise UnknownProductError(purchase.product_id)
        return product

    def _apply(
        self, owner_id: str, purchase: VerifiedStorePurchase, existing: StoreEntitlement | None
    ) -> StoreEntitlement:
        product = self._product(purchase)
        now = utc_now()
        if purchase.linked_previous_id:
            previous = self._entitlements.get(purchase.store, purchase.linked_previous_id)
            if previous is not None and previous.owner_id == owner_id:
                self._entitlements.save(
                    previous.model_copy(
                        update={"state": StoreState.REPLACED, "last_verified_at": now}
                    )
                )
        base = existing or StoreEntitlement(
            owner_id=owner_id,
            store=purchase.store,
            store_subscription_id=purchase.store_subscription_id,
            product_id=purchase.product_id,
            plan=product.plan,
            period=product.period,
            state=purchase.state,
        )
        # A refund/revocation is final for that transaction chain unless the
        # store later reports a newer renewal (a fresh expiry after revoked_at).
        state = purchase.state
        if (
            existing is not None
            and existing.state in (StoreState.REFUNDED, StoreState.REVOKED)
            and state in (StoreState.ACTIVE, StoreState.CANCELED)
            and existing.revoked_at is not None
            and (purchase.expires_at is None or purchase.expires_at <= existing.revoked_at)
        ):
            state = existing.state
        updated = base.model_copy(
            update={
                "latest_transaction_id": purchase.latest_transaction_id,
                "product_id": purchase.product_id,
                "plan": product.plan,
                "period": product.period,
                "state": state,
                "expires_at": purchase.expires_at,
                "auto_renew": purchase.auto_renew,
                "grace_expires_at": purchase.grace_expires_at,
                "revoked_at": purchase.revoked_at or base.revoked_at,
                "environment": purchase.environment,
                "last_event_at": max(purchase.event_time, base.last_event_at),
                "last_verified_at": now,
                "verification_error_at": None,
            }
        )
        saved = self._entitlements.save(updated)
        forget_request_subscription(owner_id)
        return saved

    def _flag(self, entitlement: StoreEntitlement, anomaly: str) -> None:
        logger.warning("billing anomaly: %s", anomaly)
        self._entitlements.save(entitlement.model_copy(update={"anomaly": anomaly}))
        forget_request_subscription(entitlement.owner_id)

    def _record(
        self,
        notification: StoreNotification,
        owner_id: str | None,
        store_id: str | None,
        outcome: str,
    ) -> bool:
        return self._entitlements.record_event(
            event_id=notification.event_id,
            store=notification.store,
            notification_type=(
                f"{notification.notification_type}:{notification.subtype}"
                if notification.subtype
                else notification.notification_type
            ),
            owner_id=owner_id,
            store_subscription_id=store_id,
            signed_at=notification.signed_at,
            outcome=outcome,
        )
