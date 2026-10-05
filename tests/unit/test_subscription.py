from datetime import timedelta

import pytest

from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.select_plan import SelectPlanInput, SelectPlanService
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription, SubscriptionPlan
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemorySubscriptionRepository,
)
from packages.shared.errors.base import ValidationError

_DEVELOPER_EMAILS = frozenset({"russo88fra@gmail.com", "vastaso88@gmail.com"})


def test_first_lookup_starts_a_ten_day_trial() -> None:
    repository = InMemorySubscriptionRepository()
    service = GetOrCreateSubscriptionService(repository, _DEVELOPER_EMAILS)

    result = service.execute(
        GetOrCreateSubscriptionInput(owner_id="user-1", email="owner@example.com")
    )

    assert result.subscription.plan is None
    assert result.has_access is True
    delta = result.subscription.trial_ends_at - utc_now()
    assert timedelta(days=9) < delta <= timedelta(days=10)


def test_second_lookup_reuses_the_same_subscription() -> None:
    repository = InMemorySubscriptionRepository()
    service = GetOrCreateSubscriptionService(repository, _DEVELOPER_EMAILS)
    first = service.execute(
        GetOrCreateSubscriptionInput(owner_id="user-1", email="owner@example.com")
    )

    second = service.execute(
        GetOrCreateSubscriptionInput(owner_id="user-1", email="owner@example.com")
    )

    assert second.subscription.trial_ends_at == first.subscription.trial_ends_at


def test_expired_trial_without_a_plan_loses_access() -> None:
    repository = InMemorySubscriptionRepository()
    repository.save(Subscription(owner_id="user-1", trial_ends_at=utc_now() - timedelta(days=1)))
    service = GetOrCreateSubscriptionService(repository, _DEVELOPER_EMAILS)

    result = service.execute(
        GetOrCreateSubscriptionInput(owner_id="user-1", email="owner@example.com")
    )

    assert result.has_access is False


def test_developer_allowlist_always_has_access_even_after_trial_expiry() -> None:
    repository = InMemorySubscriptionRepository()
    repository.save(Subscription(owner_id="dev-1", trial_ends_at=utc_now() - timedelta(days=1)))
    service = GetOrCreateSubscriptionService(repository, _DEVELOPER_EMAILS)

    result = service.execute(
        GetOrCreateSubscriptionInput(owner_id="dev-1", email="RUSSO88FRA@gmail.com")
    )

    assert result.is_developer is True
    assert result.has_access is True


def test_select_plan_grants_access_even_after_trial_expiry() -> None:
    repository = InMemorySubscriptionRepository()
    repository.save(Subscription(owner_id="user-1", trial_ends_at=utc_now() - timedelta(days=1)))
    select_plan = SelectPlanService(repository)
    get_status = GetOrCreateSubscriptionService(repository, _DEVELOPER_EMAILS)

    select_plan.execute(SelectPlanInput(owner_id="user-1", plan=SubscriptionPlan.PLUS))
    result = get_status.execute(
        GetOrCreateSubscriptionInput(owner_id="user-1", email="owner@example.com")
    )

    assert result.subscription.plan == SubscriptionPlan.PLUS
    assert result.has_access is True


def test_select_plan_rejects_unknown_plan() -> None:
    service = SelectPlanService(InMemorySubscriptionRepository())

    with pytest.raises(ValidationError):
        service.execute(SelectPlanInput(owner_id="user-1", plan="gold"))
