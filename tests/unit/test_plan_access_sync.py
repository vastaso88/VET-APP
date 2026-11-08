"""The backend keeps the database's copy of the test plan and of the developer
allowlist in line (scripts/setup/plan_access_rules.sql), at each status check."""

from __future__ import annotations

from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.plan_access_sync import PlanAccessSync
from packages.infrastructure.persistence.in_memory_plan_access_store import (
    InMemoryPlanAccessStore,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemorySubscriptionRepository,
)

DEV = "dev@example.com"


def _service(
    store: InMemoryPlanAccessStore, *, test_plan: str | None
) -> GetOrCreateSubscriptionService:
    return GetOrCreateSubscriptionService(
        InMemorySubscriptionRepository(),
        frozenset({DEV}),
        test_plan=test_plan,
        access_sync=PlanAccessSync(store),
    )


def test_the_test_plan_and_the_developers_reach_the_database() -> None:
    store = InMemoryPlanAccessStore()
    service = _service(store, test_plan="pro")

    service.execute(GetOrCreateSubscriptionInput(owner_id="owner-dev", email=DEV))
    service.execute(GetOrCreateSubscriptionInput(owner_id="owner-a", email="a@example.com"))

    assert store.test_plan == "pro"
    assert store.unlimited == {"owner-dev"}


def test_switching_the_test_off_reaches_the_database_too() -> None:
    store = InMemoryPlanAccessStore()
    store.test_plan = "pro"

    _service(store, test_plan=None).execute(
        GetOrCreateSubscriptionInput(owner_id="owner-a", email="a@example.com")
    )

    assert store.test_plan is None


def test_a_developer_taken_off_the_list_loses_the_exemption() -> None:
    store = InMemoryPlanAccessStore()
    store.unlimited.add("owner-x")

    _service(store, test_plan=None).execute(
        GetOrCreateSubscriptionInput(owner_id="owner-x", email="x@example.com")
    )

    assert store.unlimited == set()


def test_the_same_facts_are_written_once_per_process() -> None:
    store = InMemoryPlanAccessStore()
    sync = PlanAccessSync(store)

    for _ in range(5):
        sync.sync(owner_id="owner-a", is_developer=False, test_plan="pro")

    assert store.writes == 2


class _BrokenStore:
    def __init__(self) -> None:
        self.calls = 0

    def set_test_plan(self, plan: str | None) -> None:
        self.calls += 1
        raise RuntimeError("relation plan_access_config does not exist")

    def set_unlimited(self, owner_id: str, unlimited: bool) -> None:
        self.calls += 1
        raise RuntimeError("relation plan_access_unlimited does not exist")


def test_a_database_without_the_tables_never_changes_the_owners_answer() -> None:
    store = _BrokenStore()
    service = GetOrCreateSubscriptionService(
        InMemorySubscriptionRepository(),
        frozenset(),
        test_plan="pro",
        access_sync=PlanAccessSync(store),  # type: ignore[arg-type]
    )

    first = service.execute(GetOrCreateSubscriptionInput(owner_id="o", email="o@example.com"))
    service.execute(GetOrCreateSubscriptionInput(owner_id="o", email="o@example.com"))

    assert first.has_access is True and first.test_period is True
    # Nothing was remembered as written: the next check tries again.
    assert store.calls == 4
