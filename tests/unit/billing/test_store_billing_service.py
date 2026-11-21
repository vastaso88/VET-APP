"""Store subscriptions: rights only after server-side verification."""

from __future__ import annotations

from datetime import timedelta

import pytest

from packages.core.application.ports.store_billing import (
    StoreNotification,
    StoreRejectedError,
    StoreTemporaryError,
)
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.store_billing import (
    PurchaseOwnershipError,
    StoreBillingService,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription
from packages.core.domain.subscription.store import (
    BillingPeriod,
    ProductCatalog,
    Store,
    StoreEntitlement,
    StoreState,
    VerifiedStorePurchase,
)
from packages.infrastructure.billing.fake_store import FakeStore
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemorySubscriptionRepository,
)
from packages.infrastructure.persistence.in_memory_store_billing import (
    InMemoryStoreEntitlementRepository,
)


class World:
    def __init__(self) -> None:
        self.subscriptions = InMemorySubscriptionRepository()
        self.entitlements = InMemoryStoreEntitlementRepository()
        self.apple = FakeStore()
        self.google = FakeStore()
        self.service = StoreBillingService(
            entitlements=self.entitlements,
            subscriptions=self.subscriptions,
            verifiers={Store.APPLE: self.apple, Store.GOOGLE: self.google},
            catalog=ProductCatalog(),
            account_token_secret="test-secret-not-real",
            allowed_environments=frozenset({"sandbox"}),
        )

    def owner(self, owner_id: str, *, trial_open: bool = False) -> str:
        delta = timedelta(days=5) if trial_open else timedelta(days=-1)
        self.subscriptions.save(Subscription(owner_id=owner_id, trial_ends_at=utc_now() + delta))
        return owner_id

    def answer(
        self,
        store: Store,
        store_id: str,
        owner_id: str | None,
        *,
        product: str | None = None,
        base_plan: str | None = None,
        state: StoreState = StoreState.ACTIVE,
        days: float = 30,
        auto_renew: bool = True,
        **extra: object,
    ) -> VerifiedStorePurchase:
        purchase = VerifiedStorePurchase(
            store=store,
            store_subscription_id=store_id,
            latest_transaction_id=f"tx-{store_id}",
            product_id=product
            or ("net.quokkapet.plus.monthly" if store == Store.APPLE else "quokka_plus"),
            base_plan_id=base_plan or ("monthly" if store == Store.GOOGLE else None),
            state=state,
            expires_at=utc_now() + timedelta(days=days),
            auto_renew=auto_renew,
            environment="sandbox",
            account_token=self.service.account_token(owner_id) if owner_id else None,
            **extra,  # type: ignore[arg-type]
        )
        (self.apple if store == Store.APPLE else self.google).answers[store_id] = purchase
        return purchase


def _status(world: World, owner: str) -> object:
    return GetOrCreateSubscriptionService(
        world.subscriptions, frozenset(), store_billing=world.service
    ).execute(GetOrCreateSubscriptionInput(owner_id=owner, email="owner@example.com"))


def _notify(world: World, event_id: str, store_id: str, **kw: object) -> str:
    return world.service.handle_notification(
        StoreNotification(
            event_id=event_id,
            store=kw.pop("store", Store.APPLE),  # type: ignore[arg-type]
            notification_type=str(kw.pop("kind", "DID_RENEW")),
            signed_at=kw.pop("signed_at", utc_now()),  # type: ignore[arg-type]
            store_subscription_id=store_id,
            environment="sandbox",
            **kw,  # type: ignore[arg-type]
        )
    )


# --- trial -------------------------------------------------------------------


def test_open_trial_has_access_without_any_purchase() -> None:
    world = World()
    world.owner("a", trial_open=True)
    status = _status(world, "a")
    assert status.has_access is True and status.subscription.plan is None  # type: ignore[attr-defined]


def test_expired_trial_without_purchase_has_no_access() -> None:
    world = World()
    world.owner("a")
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_a_stored_plan_without_a_verified_purchase_is_not_honoured() -> None:
    world = World()
    world.owner("a")
    sub = world.subscriptions.get("a")
    assert sub is not None
    world.subscriptions.save(sub.model_copy(update={"plan": "ultra"}))  # e.g. old select-plan
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


# --- purchase ----------------------------------------------------------------


@pytest.mark.parametrize("store", [Store.APPLE, Store.GOOGLE])
def test_first_purchase_grants_the_plan_after_verification(store: Store) -> None:
    world = World()
    world.owner("a")
    world.answer(store, "S1", "a")
    out = world.service.verify_purchase(
        owner_id="a", store=store, store_subscription_id="S1", product_id=None
    )
    assert out.plan == "plus" and out.complete_transaction is True
    status = _status(world, "a")
    assert status.has_access is True  # type: ignore[attr-defined]
    assert status.store_subscription.store == store  # type: ignore[attr-defined]


def test_google_purchase_is_acknowledged_server_side() -> None:
    world = World()
    world.owner("a")
    world.answer(Store.GOOGLE, "T1", "a", needs_acknowledgement=True)
    world.service.verify_purchase(
        owner_id="a", store=Store.GOOGLE, store_subscription_id="T1", product_id="quokka_plus"
    )
    assert world.google.acknowledged == ["T1"]


def test_pending_purchase_grants_nothing_and_is_not_completed() -> None:
    world = World()
    world.owner("a")
    world.answer(Store.GOOGLE, "T1", "a", state=StoreState.PENDING, needs_acknowledgement=True)
    out = world.service.verify_purchase(
        owner_id="a", store=Store.GOOGLE, store_subscription_id="T1", product_id=None
    )
    assert out.plan is None and out.complete_transaction is False
    assert world.google.acknowledged == []


def test_unknown_product_is_refused() -> None:
    from packages.core.application.services.store_billing import UnknownProductError

    world = World()
    world.owner("a")
    world.answer(Store.APPLE, "S1", "a", product="com.other.gold")
    with pytest.raises(UnknownProductError):
        world.service.verify_purchase(
            owner_id="a", store=Store.APPLE, store_subscription_id="S1", product_id=None
        )


# --- forgery / another account -------------------------------------------------


def test_forged_transaction_unknown_to_the_store_is_refused() -> None:
    world = World()
    world.owner("a")
    with pytest.raises(StoreRejectedError):
        world.service.verify_purchase(
            owner_id="a", store=Store.APPLE, store_subscription_id="made-up", product_id=None
        )
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_purchase_made_by_another_account_cannot_be_claimed() -> None:
    world = World()
    world.owner("a")
    world.owner("b")
    world.answer(Store.APPLE, "S1", "a")  # token of A
    with pytest.raises(PurchaseOwnershipError) as err:
        world.service.verify_purchase(
            owner_id="b", store=Store.APPLE, store_subscription_id="S1", product_id=None
        )
    assert err.value.code == "purchase_owned_by_another_account"
    assert _status(world, "b").has_access is False  # type: ignore[attr-defined]


def test_already_bound_subscription_is_not_moved_to_another_account() -> None:
    world = World()
    world.owner("a")
    world.owner("b")
    world.answer(Store.GOOGLE, "T1", "a")
    world.service.verify_purchase(
        owner_id="a", store=Store.GOOGLE, store_subscription_id="T1", product_id=None
    )
    # Even if the store answered with B's token, the row stays with A.
    world.answer(Store.GOOGLE, "T1", "b")
    with pytest.raises(PurchaseOwnershipError):
        world.service.verify_purchase(
            owner_id="b", store=Store.GOOGLE, store_subscription_id="T1", product_id=None
        )
    entitlement = world.entitlements.get(Store.GOOGLE, "T1")
    assert entitlement is not None and entitlement.owner_id == "a"
    assert entitlement.anomaly == "claim_attempt_by_another_account"


def test_purchase_without_account_token_is_refused() -> None:
    world = World()
    world.owner("a")
    world.answer(Store.APPLE, "S1", None)
    with pytest.raises(PurchaseOwnershipError) as err:
        world.service.verify_purchase(
            owner_id="a", store=Store.APPLE, store_subscription_id="S1", product_id=None
        )
    assert err.value.code == "purchase_account_token_missing"


def test_sandbox_deployment_refuses_production_receipts_and_vice_versa() -> None:
    world = World()
    world.owner("a")
    purchase = world.answer(Store.APPLE, "S1", "a")
    world.apple.answers["S1"] = purchase.model_copy(update={"environment": "production"})
    with pytest.raises(StoreRejectedError):
        world.service.verify_purchase(
            owner_id="a", store=Store.APPLE, store_subscription_id="S1", product_id=None
        )


def test_account_token_is_stable_and_not_the_user_id() -> None:
    world = World()
    token = world.service.account_token("user-123")
    assert token == world.service.account_token("user-123")
    assert "user-123" not in token and token != world.service.account_token("user-124")


# --- lifecycle ---------------------------------------------------------------


def _bought(world: World, store: Store = Store.APPLE, store_id: str = "S1") -> None:
    world.owner("a")
    world.answer(store, store_id, "a")
    world.service.verify_purchase(
        owner_id="a", store=store, store_subscription_id=store_id, product_id=None
    )


def test_renewal_notification_extends_the_period() -> None:
    world = World()
    _bought(world)
    renewed = world.answer(Store.APPLE, "S1", "a", days=60)
    assert _notify(world, "n1", "S1", purchase=renewed) == "applied"
    entitlement = world.entitlements.get(Store.APPLE, "S1")
    assert entitlement is not None and entitlement.expires_at == renewed.expires_at


def test_cancellation_keeps_access_until_expiry_then_expires() -> None:
    world = World()
    _bought(world)
    canceled = world.answer(Store.APPLE, "S1", "a", state=StoreState.CANCELED, auto_renew=False)
    _notify(world, "n1", "S1", purchase=canceled, kind="DID_CHANGE_RENEWAL_STATUS")
    status = _status(world, "a")
    assert status.has_access is True  # type: ignore[attr-defined]
    assert status.store_subscription.auto_renew is False  # type: ignore[attr-defined]
    expired = world.answer(Store.APPLE, "S1", "a", state=StoreState.EXPIRED, days=-1)
    _notify(world, "n2", "S1", purchase=expired, kind="EXPIRED")
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_expiry_by_time_alone_removes_access_without_notification() -> None:
    world = World()
    _bought(world)
    entitlement = world.entitlements.get(Store.APPLE, "S1")
    assert entitlement is not None
    world.entitlements.save(entitlement.model_copy(update={"expires_at": utc_now()}))
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


@pytest.mark.parametrize(
    "flag,state", [("refund", StoreState.REFUNDED), ("revoke", StoreState.REVOKED)]
)
def test_refund_and_revocation_remove_access(flag: str, state: StoreState) -> None:
    world = World()
    _bought(world)
    purchase = world.answer(Store.APPLE, "S1", "a")
    _notify(world, "n1", "S1", purchase=purchase, kind=flag.upper(), **{flag: True})
    entitlement = world.entitlements.get(Store.APPLE, "S1")
    assert entitlement is not None and entitlement.state == state
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_grace_period_keeps_access_billing_retry_does_not() -> None:
    world = World()
    _bought(world)
    grace = world.answer(
        Store.APPLE,
        "S1",
        "a",
        state=StoreState.IN_GRACE_PERIOD,
        days=-0.1,
        grace_expires_at=utc_now() + timedelta(days=3),
    )
    _notify(world, "n1", "S1", purchase=grace, kind="DID_FAIL_TO_RENEW")
    assert _status(world, "a").has_access is True  # type: ignore[attr-defined]
    retry = world.answer(Store.APPLE, "S1", "a", state=StoreState.BILLING_RETRY, days=-0.1)
    _notify(world, "n2", "S1", purchase=retry, kind="GRACE_PERIOD_EXPIRED")
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_google_upgrade_replaces_the_old_token_and_raises_the_plan() -> None:
    world = World()
    _bought(world, Store.GOOGLE, "T1")
    world.answer(
        Store.GOOGLE,
        "T2",
        "a",
        product="quokka_ultra",
        base_plan="yearly",
        days=365,
        linked_previous_id="T1",
    )
    out = world.service.verify_purchase(
        owner_id="a", store=Store.GOOGLE, store_subscription_id="T2", product_id="quokka_ultra"
    )
    assert out.plan == "ultra"
    old = world.entitlements.get(Store.GOOGLE, "T1")
    assert old is not None and old.state == StoreState.REPLACED


def test_apple_downgrade_takes_effect_with_the_store_answer() -> None:
    world = World()
    world.owner("a")
    world.answer(Store.APPLE, "S1", "a", product="net.quokkapet.pro.yearly")
    world.service.verify_purchase(
        owner_id="a", store=Store.APPLE, store_subscription_id="S1", product_id=None
    )
    assert world.subscriptions.get("a").plan == "pro"  # type: ignore[union-attr]
    # At renewal Apple reports the lower product on the same original id.
    lower = world.answer(Store.APPLE, "S1", "a", product="net.quokkapet.plus.yearly")
    _notify(world, "n1", "S1", purchase=lower)
    assert world.subscriptions.get("a").plan == "plus"  # type: ignore[union-attr]


# --- notifications: duplicates and order ----------------------------------------


def test_duplicate_notification_is_processed_once() -> None:
    world = World()
    _bought(world)
    expired = world.answer(Store.APPLE, "S1", "a", state=StoreState.EXPIRED, days=-1)
    assert _notify(world, "same", "S1", purchase=expired) == "applied"
    world.answer(Store.APPLE, "S1", "a")
    renewed = world.answer(Store.APPLE, "S1", "a", days=40)
    assert _notify(world, "same", "S1", purchase=renewed) == "duplicate"
    entitlement = world.entitlements.get(Store.APPLE, "S1")
    assert entitlement is not None and entitlement.state == StoreState.EXPIRED


def test_out_of_order_older_notification_does_not_roll_back() -> None:
    world = World()
    _bought(world)
    newer = world.answer(Store.APPLE, "S1", "a", days=60)
    _notify(world, "n2", "S1", purchase=newer, signed_at=utc_now())
    older = world.answer(Store.APPLE, "S1", "a", state=StoreState.EXPIRED, days=-1)
    outcome = _notify(world, "n1", "S1", purchase=older, signed_at=utc_now() - timedelta(hours=2))
    assert outcome == "stale_ignored"
    assert _status(world, "a").has_access is True  # type: ignore[attr-defined]


def test_google_notification_refetches_state_from_the_api() -> None:
    world = World()
    _bought(world, Store.GOOGLE, "T1")
    world.answer(Store.GOOGLE, "T1", "a", state=StoreState.ON_HOLD, days=-1)
    assert _notify(world, "m1", "T1", store=Store.GOOGLE, kind="SUBSCRIPTION_5") == "applied"
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_notification_for_an_unknown_account_grants_nothing() -> None:
    world = World()
    world.owner("a")
    purchase = world.answer(Store.APPLE, "S9", None)
    assert _notify(world, "n1", "S9", purchase=purchase) == "unmatched_owner"
    assert world.entitlements.list_all() == []


def test_notification_before_client_verification_binds_by_account_token() -> None:
    world = World()
    world.owner("a")
    purchase = world.answer(Store.APPLE, "S1", "a")  # token issued to A
    assert _notify(world, "n1", "S1", purchase=purchase, kind="SUBSCRIBED") == "applied"
    assert _status(world, "a").has_access is True  # type: ignore[attr-defined]


# --- restore -------------------------------------------------------------------


def test_restore_on_a_new_device_recovers_own_purchases_only() -> None:
    world = World()
    world.owner("a")
    world.owner("b")
    world.answer(Store.APPLE, "S1", "a")
    world.answer(Store.APPLE, "S2", "b")
    restored = world.service.restore(owner_id="a", store=Store.APPLE, ids=["S1", "S2", "nope"])
    assert [r.entitlement.store_subscription_id for r in restored] == ["S1"]
    assert _status(world, "a").has_access is True  # type: ignore[attr-defined]
    assert _status(world, "b").has_access is False  # type: ignore[attr-defined]


# --- temporary errors ------------------------------------------------------------


def test_store_outage_on_purchase_grants_nothing() -> None:
    world = World()
    world.owner("a")
    world.answer(Store.APPLE, "S1", "a")
    world.apple.down = True
    with pytest.raises(StoreTemporaryError):
        world.service.verify_purchase(
            owner_id="a", store=Store.APPLE, store_subscription_id="S1", product_id=None
        )
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_store_outage_on_reconcile_keeps_verified_right_for_bounded_time() -> None:
    world = World()
    _bought(world)
    entitlement = world.entitlements.get(Store.APPLE, "S1")
    assert entitlement is not None
    world.entitlements.save(
        entitlement.model_copy(
            update={
                "expires_at": utc_now() - timedelta(hours=1),
                "last_verified_at": utc_now() - timedelta(days=1),
            }
        )
    )
    world.apple.down = True
    assert world.service.reconcile() == {"checked": 1, "updated": 0, "errors": 1}
    assert _status(world, "a").has_access is True  # type: ignore[attr-defined]
    stored = world.entitlements.get(Store.APPLE, "S1")
    assert stored is not None
    world.entitlements.save(
        stored.model_copy(update={"expires_at": utc_now() - timedelta(hours=25)})
    )
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_tolerance_never_applies_to_a_cancelled_subscription() -> None:
    entitlement = StoreEntitlement(
        owner_id="a",
        store=Store.APPLE,
        store_subscription_id="S1",
        product_id="p",
        plan="plus",
        period=BillingPeriod.MONTHLY,
        state=StoreState.CANCELED,
        expires_at=utc_now() - timedelta(minutes=5),
        verification_error_at=utc_now(),
    )
    assert entitlement.grants_access(tolerance=timedelta(hours=24)) is False


def test_reconcile_applies_the_store_state() -> None:
    world = World()
    _bought(world)
    entitlement = world.entitlements.get(Store.APPLE, "S1")
    assert entitlement is not None
    world.entitlements.save(
        entitlement.model_copy(update={"last_verified_at": utc_now() - timedelta(days=1)})
    )
    world.answer(Store.APPLE, "S1", "a", state=StoreState.REVOKED, days=-1)
    assert world.service.reconcile()["updated"] == 1
    assert _status(world, "a").has_access is False  # type: ignore[attr-defined]


def test_admin_test_grant_is_a_separate_marked_entitlement() -> None:
    world = World()
    world.owner("a")
    entitlement = world.service.grant_admin_test("a", "pro", 7)
    assert entitlement.store == Store.ADMIN_TEST and entitlement.anomaly == "admin_test_grant"
    assert _status(world, "a").has_access is True  # type: ignore[attr-defined]


# --- team / demo accounts ------------------------------------------------------


def _status_as(
    world: World,
    owner: str,
    email: str,
    overrides: dict[str, str],
    verified: bool | None = True,
) -> object:
    return GetOrCreateSubscriptionService(
        world.subscriptions,
        frozenset({"dev@example.com"}),
        store_billing=world.service,
        plan_overrides=overrides,
    ).execute(GetOrCreateSubscriptionInput(owner_id=owner, email=email, email_verified=verified))


def test_override_needs_a_confirmed_address() -> None:
    """Signing up with a team address without confirming it earns nothing."""
    world = World()
    world.owner("intruder")
    overrides = {"team@example.com": "ultra"}
    for verified in (False, None):
        status = _status_as(world, "intruder", "team@example.com", overrides, verified)
        assert status.has_access is False  # type: ignore[attr-defined]
        assert status.subscription.plan is None  # type: ignore[attr-defined]
        assert status.plan_source != "override"  # type: ignore[attr-defined]


def test_lookup_that_cannot_tell_keeps_a_confirmed_override() -> None:
    """The plan-limits lookup (verification unknown) neither grants the
    override nor takes away the one a confirmed request already saved."""
    world = World()
    world.owner("team")
    overrides = {"team@example.com": "pro"}
    assert _status_as(world, "team", "team@example.com", overrides).subscription.plan == "pro"  # type: ignore[attr-defined]
    kept = _status_as(world, "team", "team@example.com", overrides, verified=None)
    assert kept.subscription.plan == "pro"  # type: ignore[attr-defined]
    assert kept.plan_source == "override"  # type: ignore[attr-defined]
    # An explicit "not confirmed" (e.g. the address was changed) drops it.
    dropped = _status_as(world, "team", "team@example.com", overrides, verified=False)
    assert dropped.subscription.plan is None  # type: ignore[attr-defined]


def test_override_keeps_a_demo_account_on_its_plan_without_the_store() -> None:
    world = World()
    world.owner("demo")
    status = _status_as(world, "demo", "Demo@Example.com", {"demo@example.com": "ultra"})
    assert status.has_access is True  # type: ignore[attr-defined]
    assert status.subscription.plan == "ultra"  # type: ignore[attr-defined]
    assert status.plan_source == "override"  # type: ignore[attr-defined]
    # Removing the override hands the account back to the store: no purchase, no plan.
    assert _status_as(world, "demo", "demo@example.com", {}).has_access is False  # type: ignore[attr-defined]


def test_developer_keeps_unlimited_access_with_billing_on() -> None:
    world = World()
    world.owner("dev")
    status = _status_as(world, "dev", "dev@example.com", {})
    assert status.has_access is True and status.limits is None  # type: ignore[attr-defined]
    assert status.plan_source == "developer"  # type: ignore[attr-defined]


def test_override_with_an_unknown_plan_is_ignored() -> None:
    world = World()
    world.owner("demo")
    status = _status_as(world, "demo", "demo@example.com", {"demo@example.com": "gold"})
    assert status.has_access is False  # type: ignore[attr-defined]


def test_override_parsing() -> None:
    from packages.bootstrap.container import _parse_plan_overrides

    assert _parse_plan_overrides(
        " A@example.com:Pro , bad, b@example.com:gold,c@example.com:plus"
    ) == {
        "a@example.com": "pro",
        "c@example.com": "plus",
    }
