from datetime import timedelta

import pytest

from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.select_plan import (
    PlanRequiresStorePurchaseError,
    SelectPlanInput,
    SelectPlanService,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.models import Subscription, SubscriptionPlan
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemorySubscriptionRepository,
)
from packages.shared.errors.base import ValidationError

_DEVELOPER_EMAILS = frozenset({"dev1@example.com", "dev2@example.com"})


def test_first_lookup_starts_a_fourteen_day_trial() -> None:
    repository = InMemorySubscriptionRepository()
    service = GetOrCreateSubscriptionService(repository, _DEVELOPER_EMAILS)

    result = service.execute(
        GetOrCreateSubscriptionInput(owner_id="user-1", email="owner@example.com")
    )

    assert result.subscription.plan is None
    assert result.has_access is True
    delta = result.subscription.trial_ends_at - utc_now()
    assert timedelta(days=13) < delta <= timedelta(days=14)


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
        GetOrCreateSubscriptionInput(owner_id="dev-1", email="DEV1@example.com")
    )

    assert result.is_developer is True
    assert result.has_access is True


def test_select_plan_never_grants_a_paid_plan() -> None:
    repository = InMemorySubscriptionRepository()
    repository.save(Subscription(owner_id="user-1", trial_ends_at=utc_now() - timedelta(days=1)))
    select_plan = SelectPlanService(repository)
    get_status = GetOrCreateSubscriptionService(repository, _DEVELOPER_EMAILS)

    with pytest.raises(PlanRequiresStorePurchaseError):
        select_plan.execute(SelectPlanInput(owner_id="user-1", plan=SubscriptionPlan.PLUS))
    result = get_status.execute(
        GetOrCreateSubscriptionInput(owner_id="user-1", email="owner@example.com")
    )

    assert result.subscription.plan is None
    assert result.has_access is False


def test_select_plan_rejects_unknown_plan() -> None:
    service = SelectPlanService(InMemorySubscriptionRepository())

    with pytest.raises(ValidationError):
        service.execute(SelectPlanInput(owner_id="user-1", plan="gold"))


def test_an_unconfirmed_developer_address_is_not_a_developer() -> None:
    """Anyone can sign up with a team address: only a confirmed one counts."""
    service = GetOrCreateSubscriptionService(InMemorySubscriptionRepository(), _DEVELOPER_EMAILS)
    for verified, expected in ((False, False), (True, True), (None, True)):
        result = service.execute(
            GetOrCreateSubscriptionInput(
                owner_id=f"dev-{verified}", email="dev1@example.com", email_verified=verified
            )
        )
        assert result.is_developer is expected


def test_allowlist_email_blanks_an_unconfirmed_address() -> None:
    from types import SimpleNamespace

    from apps.api.dependencies.subscription import allowlist_email

    confirmed = SimpleNamespace(email=" Dev1@Example.com ", email_verified=True)
    unconfirmed = SimpleNamespace(email="dev1@example.com", email_verified=False)
    assert allowlist_email(confirmed) == "dev1@example.com"
    assert allowlist_email(unconfirmed) == ""
    assert "" not in _DEVELOPER_EMAILS


def test_a_blank_developer_entry_is_dropped() -> None:
    from packages.bootstrap.container import ApplicationContainer
    from packages.shared.config.settings import Settings

    settings = Settings().model_copy(update={"developer_emails": ["dev1@example.com", " ", ""]})
    assert "" not in ApplicationContainer(settings).developer_emails
