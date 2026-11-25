"""QK-05a / QK-05b at service level: the per-request memo of the identity and of the
subscription outcome (packages/shared/auth_context.py,
GetOrCreateSubscriptionService.execute).

The HTTP behaviour (one read on a route with several dependencies, two owners at the same
time, 402 unchanged) is in tests/integration/test_subscription_once_per_request.py."""

from __future__ import annotations

from datetime import timedelta
from typing import Any

import pytest

from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.store_billing import StoreBillingService
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription
from packages.core.domain.subscription.store import (
    ProductCatalog,
    Store,
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
from packages.shared import auth_context
from packages.shared.auth_context import (
    access_token_context,
    forget_request_subscription,
    get_access_token,
    get_identity_memo,
)

OWNER_A = "11111111-1111-4111-8111-111111111111"
OWNER_B = "22222222-2222-4222-8222-222222222222"
EMAIL = "owner@example.com"


class _Reads(InMemorySubscriptionRepository):
    """The in-memory repository that counts how many times a subscription is read."""

    def __init__(self) -> None:
        super().__init__()
        self.reads = 0

    def get(self, owner_id: str) -> Subscription | None:
        self.reads += 1
        return super().get(owner_id)


def _ask(
    service: GetOrCreateSubscriptionService,
    owner_id: str = OWNER_A,
    *,
    email: str = EMAIL,
    verified: bool | None = True,
) -> Any:
    return service.execute(
        GetOrCreateSubscriptionInput(owner_id=owner_id, email=email, email_verified=verified)
    )


def _open_trial(repository: InMemorySubscriptionRepository, owner_id: str = OWNER_A) -> None:
    repository.save(Subscription(owner_id=owner_id, trial_ends_at=utc_now() + timedelta(days=5)))


# --- QK-05a: nested contexts keep what the outer one remembered --------------------


def test_an_inner_token_context_gives_back_the_outer_memo_when_it_ends() -> None:
    with access_token_context("outer-token"):
        outer = get_identity_memo()
        assert outer is not None
        outer.put("outer-token", "outer-identity")

        with access_token_context("inner-token"):
            inner = get_identity_memo()
            assert inner is not None and inner is not outer
            assert inner.get("outer-token") is None  # a fresh, empty memo
            assert get_access_token() == "inner-token"

        # Back in the outer one: same token, same memo, what it remembered is still there.
        assert get_access_token() == "outer-token"
        assert get_identity_memo() is outer
        assert outer.get("outer-token") == "outer-identity"

    assert get_identity_memo() is None and get_access_token() is None


def test_the_outer_memo_is_restored_even_when_the_inner_block_fails() -> None:
    with access_token_context("outer-token"):
        outer = get_identity_memo()
        with pytest.raises(RuntimeError), access_token_context("inner-token"):
            raise RuntimeError("boom")
        assert get_identity_memo() is outer and get_access_token() == "outer-token"


def test_set_and_reset_work_as_a_pair_for_a_single_request() -> None:
    state = auth_context.set_access_token("request-token")
    try:
        assert get_access_token() == "request-token" and get_identity_memo() is not None
    finally:
        auth_context.reset_access_token(state)

    assert get_access_token() is None and get_identity_memo() is None


# --- QK-05b: one subscription read per request ------------------------------------


def test_the_outcome_is_computed_once_per_request_and_not_at_all_remembered_outside_one() -> None:
    reads = _Reads()
    _open_trial(reads)
    service = GetOrCreateSubscriptionService(reads, frozenset())
    reads.reads = 0

    with access_token_context("token-a"):
        first = _ask(service)
        second = _ask(service)
        assert (first.has_access, second.has_access) == (True, True)
        assert reads.reads == 1

    # Outside a request nothing is kept: two calls, two reads.
    reads.reads = 0
    _ask(service)
    _ask(service)
    assert reads.reads == 2


def test_the_next_request_never_sees_the_outcome_of_the_previous_one() -> None:
    reads = _Reads()
    _open_trial(reads)
    service = GetOrCreateSubscriptionService(reads, frozenset())

    with access_token_context("token-a"):
        assert _ask(service).has_access is True

    # The trial ends between the two requests.
    reads.save(Subscription(owner_id=OWNER_A, trial_ends_at=utc_now() - timedelta(days=1)))
    with access_token_context("token-a"):
        assert _ask(service).has_access is False


def test_the_trial_running_out_changes_the_answer_of_the_following_request_only() -> None:
    reads = _Reads()
    reads.save(Subscription(owner_id=OWNER_A, trial_ends_at=utc_now() + timedelta(seconds=1)))
    service = GetOrCreateSubscriptionService(reads, frozenset())

    with access_token_context("token-a"):
        before = _ask(service)
        # Whatever the clock says now, inside this request the answer is the one given.
        reads.save(Subscription(owner_id=OWNER_A, trial_ends_at=utc_now() - timedelta(days=1)))
        assert _ask(service).has_access is before.has_access
    with access_token_context("token-a"):
        assert _ask(service).has_access is False


def test_each_owner_and_each_address_has_its_own_entry() -> None:
    reads = _Reads()
    _open_trial(reads, OWNER_A)
    reads.save(Subscription(owner_id=OWNER_B, trial_ends_at=utc_now() - timedelta(days=1)))
    service = GetOrCreateSubscriptionService(reads, frozenset())

    with access_token_context("token-a"):
        assert _ask(service, OWNER_A).has_access is True
        assert _ask(service, OWNER_B).has_access is False
        assert _ask(service, OWNER_A).has_access is True
        assert _ask(service, OWNER_B).has_access is False
        # A different address for the same owner is a different question.
        before = reads.reads
        _ask(service, OWNER_A, email="other@example.com")
        assert reads.reads == before + 1


def test_a_lookup_that_cannot_tell_reuses_a_confirmed_one_but_never_an_unconfirmed_one() -> None:
    reads = _Reads()
    _open_trial(reads)
    service = GetOrCreateSubscriptionService(reads, frozenset())

    with access_token_context("confirmed"):
        _ask(service, verified=True)
        reads.reads = 0
        _ask(service, verified=None)  # the plan-limits lookup inside the services
        assert reads.reads == 0

    with access_token_context("unconfirmed"):
        _ask(service, verified=False)
        reads.reads = 0
        _ask(service, verified=None)
        assert reads.reads == 1


def test_a_confirmed_team_address_never_leaks_its_override_to_an_unconfirmed_lookup() -> None:
    reads = _Reads()
    _open_trial(reads)
    service = GetOrCreateSubscriptionService(
        reads, frozenset(), plan_overrides={EMAIL: "ultra"}, trial_days=14
    )

    with access_token_context("confirmed"):
        assert _ask(service, verified=True).subscription.plan == "ultra"
    # Another request, same owner id, same address but NOT confirmed: no override is granted
    # from the memory of the first one (a new request starts empty).
    reads.save(Subscription(owner_id=OWNER_A, trial_ends_at=utc_now() + timedelta(days=5)))
    with access_token_context("unconfirmed"):
        assert _ask(service, verified=False).subscription.plan is None


def test_what_a_caller_edits_is_not_what_the_next_caller_reads() -> None:
    reads = _Reads()
    _open_trial(reads)
    service = GetOrCreateSubscriptionService(reads, frozenset())

    with access_token_context("token-a"):
        first = _ask(service)
        first.has_access = False
        first.subscription.plan = "ultra"
        second = _ask(service)
        assert second.has_access is True and second.subscription.plan is None


def test_without_a_token_nothing_is_remembered() -> None:
    reads = _Reads()
    _open_trial(reads)
    service = GetOrCreateSubscriptionService(reads, frozenset())

    with access_token_context(None):
        reads.reads = 0
        _ask(service)
        _ask(service)
        assert reads.reads == 2


def test_a_failure_is_not_remembered() -> None:
    class Flaky(_Reads):
        broken = True

        def get(self, owner_id: str) -> Subscription | None:
            if self.broken:
                raise RuntimeError("database down")
            return super().get(owner_id)

    reads = Flaky()
    _open_trial(reads)
    service = GetOrCreateSubscriptionService(reads, frozenset())

    with access_token_context("token-a"):
        with pytest.raises(RuntimeError):
            _ask(service)
        reads.broken = False
        assert _ask(service).has_access is True


# --- invalidation: a plan or a state changes inside the same request ---------------


class _World:
    def __init__(self) -> None:
        self.subscriptions = _Reads()
        self.entitlements = InMemoryStoreEntitlementRepository()
        self.apple = FakeStore()
        self.billing = StoreBillingService(
            entitlements=self.entitlements,
            subscriptions=self.subscriptions,
            verifiers={Store.APPLE: self.apple},
            catalog=ProductCatalog(),
            account_token_secret="test-secret-not-real",
            allowed_environments=frozenset({"sandbox"}),
        )
        self.service = GetOrCreateSubscriptionService(
            self.subscriptions, frozenset(), store_billing=self.billing
        )

    def buy(self, owner_id: str, store_id: str = "apple-sub-1") -> None:
        self.apple.answers[store_id] = VerifiedStorePurchase(
            store=Store.APPLE,
            store_subscription_id=store_id,
            latest_transaction_id=f"tx-{store_id}",
            product_id="net.quokkapet.plus.monthly",
            state=StoreState.ACTIVE,
            expires_at=utc_now() + timedelta(days=30),
            auto_renew=True,
            environment="sandbox",
            account_token=self.billing.account_token(owner_id),
        )


def test_a_verified_purchase_in_the_same_request_updates_the_outcome() -> None:
    world = _World()
    world.subscriptions.save(
        Subscription(owner_id=OWNER_A, trial_ends_at=utc_now() - timedelta(days=1))
    )
    world.buy(OWNER_A)

    with access_token_context("token-a"):
        before = _ask(world.service)
        assert before.has_access is False and before.subscription.plan is None

        world.billing.verify_purchase(
            owner_id=OWNER_A,
            store=Store.APPLE,
            store_subscription_id="apple-sub-1",
            product_id=None,
        )

        after = _ask(world.service)
        assert after.has_access is True and after.subscription.plan == "plus"


def test_restoring_purchases_in_the_same_request_updates_the_outcome() -> None:
    world = _World()
    world.subscriptions.save(
        Subscription(owner_id=OWNER_A, trial_ends_at=utc_now() - timedelta(days=1))
    )
    world.buy(OWNER_A)

    with access_token_context("token-a"):
        assert _ask(world.service).has_access is False
        world.billing.restore(owner_id=OWNER_A, store=Store.APPLE, ids=["apple-sub-1"])
        assert _ask(world.service).subscription.plan == "plus"


def test_a_team_grant_in_the_same_request_updates_the_outcome() -> None:
    world = _World()
    world.subscriptions.save(
        Subscription(owner_id=OWNER_A, trial_ends_at=utc_now() - timedelta(days=1))
    )

    with access_token_context("token-a"):
        assert _ask(world.service).has_access is False
        world.billing.grant_admin_test(OWNER_A, "pro", 3)
        assert _ask(world.service).subscription.plan == "pro"


def test_a_change_of_one_owner_leaves_the_other_owners_entry_alone() -> None:
    world = _World()
    _open_trial(world.subscriptions, OWNER_A)
    _open_trial(world.subscriptions, OWNER_B)

    with access_token_context("token-a"):
        _ask(world.service, OWNER_A)
        _ask(world.service, OWNER_B)
        reads = world.subscriptions.reads
        forget_request_subscription(OWNER_A)
        _ask(world.service, OWNER_B)  # still remembered
        assert world.subscriptions.reads == reads
        _ask(world.service, OWNER_A)  # asked again
        assert world.subscriptions.reads > reads


def test_entries_of_one_owner_never_disagree_after_a_lookup_that_saved_something() -> None:
    """Billing off, a team address with an override: a lookup that cannot tell, then a
    confirmed one (which saves the plan), then the first kind again. The last answer must be
    what the service says without any memo, not the stale first one."""

    def fresh() -> GetOrCreateSubscriptionService:
        repository = _Reads()
        _open_trial(repository)
        return GetOrCreateSubscriptionService(
            repository, frozenset(), plan_overrides={EMAIL: "pro"}
        )

    without_memo = fresh()
    _ask(without_memo, verified=None)
    _ask(without_memo, verified=True)
    expected = _ask(without_memo, verified=None).subscription.plan
    assert expected == "pro"

    with access_token_context("token-a"):
        service = fresh()
        first = _ask(service, verified=None)
        assert first.subscription.plan is None  # nothing earned yet
        _ask(service, verified=True)  # saves the override
        assert _ask(service, verified=None).subscription.plan == expected
