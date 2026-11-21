from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime, timedelta
from typing import TYPE_CHECKING

from pydantic import BaseModel

from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.application.services.plan_access_sync import PlanAccessSync
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.limits import (
    DEFAULT_MAX_MEMORIAL_PETS,
    LIMITS_BY_PLAN,
    PlanLimits,
    effective_limits,
)
from packages.core.domain.subscription.models import Subscription, SubscriptionPlan
from packages.core.domain.subscription.retention import data_kept_until
from packages.core.domain.subscription.store import best_plan

PLAN_KEYS = SubscriptionPlan.ALL

if TYPE_CHECKING:
    from packages.core.application.services.store_billing import StoreBillingService

logger = logging.getLogger(__name__)


class GetOrCreateSubscriptionInput(BaseModel):
    owner_id: str
    email: str
    # Whether the provider confirmed [email]. True: the request's token says so.
    # False: not confirmed. None: the caller cannot tell (the plan-limits lookup
    # inside the services). Only True can grant a BILLING_PLAN_OVERRIDES plan.
    email_verified: bool | None = None


class StoreSubscriptionView(BaseModel):
    store: str
    product_id: str
    plan: str
    period: str
    state: str
    expires_at: datetime | None
    auto_renew: bool
    grace_expires_at: datetime | None = None
    last_verified_at: datetime
    grants_access: bool


class GetOrCreateSubscriptionOutput(BaseModel):
    subscription: Subscription
    is_developer: bool
    has_access: bool
    # What this owner is allowed right now; None = no limits (developer).
    limits: PlanLimits | None = None
    # The limits of every plan, so the app shows the same numbers the
    # backend enforces without keeping a copy of them.
    plan_limits: dict[str, PlanLimits] = LIMITS_BY_PLAN
    # How many pets one owner may keep in Ricordi, the same for every plan
    # (MEMORIAL_PETS_MAX): they do not count towards the plan's pets, this is
    # what bounds them. The database enforces it; the app only reads it here.
    max_memorial_pets: int = DEFAULT_MAX_MEMORIAL_PETS
    # True while the deployment runs a public test (SUBSCRIPTION_TEST_PLAN):
    # the plan above is the test plan, not something the owner chose or paid.
    test_period: bool = False
    # Only for an owner whose access is over: when their data is erased if
    # nothing changes (four months after the access was lost). None otherwise.
    data_kept_until: datetime | None = None
    # The verified store subscription behind the plan (Apple/Google), or the
    # most recent one when none grants access (to show "expired"/"refunded").
    store_subscription: StoreSubscriptionView | None = None
    # Where the access comes from: store | override (team/demo account, no
    # store) | developer | test_period | trial | legacy (billing off) | None.
    plan_source: str | None = None


class GetOrCreateSubscriptionService:
    """Starts the 14-day free trial (spec: no card required) on first
    lookup, and reports whether the owner currently has access — always
    true for the developer allowlist, otherwise trial-or-plan.

    [test_plan] is the deployment's public-test switch: when it names a
    plan, every owner is reported on that plan with access and its limits,
    whatever the stored row says. The plan is only reported, never saved, so
    switching the test off puts every account back exactly where it was.

    It also keeps the retention clock (retention.py): the first time an
    account is seen without access its day D is stamped, and it is cleared
    when the account has access again. During the public test nobody is
    without access, so the clock is cleared and does not run; the end of the
    test starts it afresh."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        developer_emails: frozenset[str],
        test_plan: str | None = None,
        access_sync: PlanAccessSync | None = None,
        max_memorial_pets: int = DEFAULT_MAX_MEMORIAL_PETS,
        trial_days: int = 14,
        store_billing: StoreBillingService | None = None,
        plan_overrides: dict[str, str] | None = None,
        plan_limits_provider: Callable[[], dict[str, PlanLimits]] | None = None,
    ) -> None:
        self._plan_limits_provider = plan_limits_provider
        self._plan_overrides = {
            k.strip().lower(): v for k, v in (plan_overrides or {}).items() if v in PLAN_KEYS
        }
        # With store billing on, the plan is only what a verified store
        # subscription says (StoreBillingService.sync_plan).
        self._store_billing = store_billing
        self._trial_days = trial_days
        self._repository = repository
        self._developer_emails = developer_emails
        self._test_plan = test_plan
        # Tells the database rules on the app's direct writes the two facts
        # only the backend knows (scripts/setup/plan_access_rules.sql).
        self._access_sync = access_sync
        self._max_memorial_pets = max_memorial_pets

    def execute(self, data: GetOrCreateSubscriptionInput) -> GetOrCreateSubscriptionOutput:
        plan_limits = self._plan_limits_provider() if self._plan_limits_provider else LIMITS_BY_PLAN
        subscription = self._repository.get(data.owner_id)
        if subscription is None:
            subscription = self._repository.create_trial(
                Subscription(
                    owner_id=data.owner_id,
                    trial_ends_at=utc_now() + timedelta(days=self._trial_days),
                )
            )

        email = data.email.strip().lower()
        override = self._plan_overrides.get(email) if self._test_plan is None else None
        if override is not None and data.email_verified is not True:
            # Anyone can sign up with a team address: an unconfirmed one never
            # earns the override. A caller that cannot tell may only keep the
            # plan a confirmed request already saved for this same account.
            if not (data.email_verified is None and subscription.plan == override):
                override = None
        store_view: StoreSubscriptionView | None = None
        if override is not None:
            # Team/demo account (BILLING_PLAN_OVERRIDES, environment only): a
            # fixed plan without the store. Saved so the database rules on the
            # app's direct writes see it too; removing the override hands the
            # account back to the store on the next check.
            if subscription.plan != override:
                subscription = self._repository.save(
                    subscription.model_copy(update={"plan": override})
                )
            plan_source: str | None = "override"
        elif self._store_billing is not None and self._test_plan is None:
            plan = self._store_billing.sync_plan(data.owner_id)
            subscription = subscription.model_copy(update={"plan": plan})
            store_view = self._store_view(data.owner_id)
            plan_source = "store" if subscription.plan is not None else None
        else:
            plan_source = "legacy" if subscription.plan is not None else None

        # An explicitly unconfirmed address is never a developer. Callers that
        # cannot tell (None) receive only confirmed addresses (allowlist_email).
        is_developer = email in self._developer_emails and data.email_verified is not False
        if is_developer:
            plan_source = "developer"
        elif self._test_plan is not None:
            plan_source = "test_period"
        elif plan_source is None and subscription.is_trial_active():
            plan_source = "trial"
        if self._access_sync is not None:
            self._access_sync.sync(
                owner_id=data.owner_id,
                is_developer=is_developer,
                test_plan=self._test_plan,
                max_memorial_pets=self._max_memorial_pets,
            )
        has_access = subscription.has_access(is_developer=is_developer)
        subscription = self._keep_retention_clock(
            subscription, without_access=not has_access and self._test_plan is None
        )

        if self._test_plan is not None:
            reported = subscription.model_copy(update={"plan": self._test_plan})
            return GetOrCreateSubscriptionOutput(
                subscription=reported,
                is_developer=is_developer,
                has_access=True,
                limits=effective_limits(
                    reported, is_developer=is_developer, plan_limits=plan_limits
                ),
                plan_limits=plan_limits,
                max_memorial_pets=self._max_memorial_pets,
                test_period=True,
                plan_source=plan_source,
            )

        return GetOrCreateSubscriptionOutput(
            subscription=subscription,
            is_developer=is_developer,
            has_access=has_access,
            limits=effective_limits(
                subscription, is_developer=is_developer, plan_limits=plan_limits
            ),
            plan_limits=plan_limits,
            max_memorial_pets=self._max_memorial_pets,
            data_kept_until=(
                data_kept_until(subscription.access_lost_at)
                if not has_access and subscription.access_lost_at is not None
                else None
            ),
            store_subscription=store_view,
            plan_source=plan_source,
        )

    def _store_view(self, owner_id: str) -> StoreSubscriptionView | None:
        assert self._store_billing is not None
        items = self._store_billing.entitlements_for(owner_id)
        if not items:
            return None
        tolerance = self._store_billing.tolerance
        chosen = best_plan(items, tolerance=tolerance) or max(items, key=lambda e: e.last_event_at)
        return StoreSubscriptionView(
            store=chosen.store,
            product_id=chosen.product_id,
            plan=chosen.plan,
            period=chosen.period,
            state=chosen.state,
            expires_at=chosen.expires_at,
            auto_renew=chosen.auto_renew,
            grace_expires_at=chosen.grace_expires_at,
            last_verified_at=chosen.last_verified_at,
            grants_access=chosen.grants_access(tolerance=tolerance),
        )

    def _keep_retention_clock(
        self, subscription: Subscription, *, without_access: bool
    ) -> Subscription:
        """Stamps day D when the account is first seen without access and
        clears it when it has access again. Best effort: this bookkeeping
        never decides access, so a failure (the column may not exist yet) is
        logged and the account is treated exactly as before."""
        try:
            if without_access and subscription.access_lost_at is None:
                now = utc_now()
                self._repository.set_access_lost_at(subscription.owner_id, now)
                return subscription.model_copy(update={"access_lost_at": now})
            if not without_access and subscription.access_lost_at is not None:
                self._repository.set_access_lost_at(subscription.owner_id, None)
                return subscription.model_copy(update={"access_lost_at": None})
        except Exception:  # noqa: BLE001 - bookkeeping must not decide access
            logger.warning("could not update the retention clock of an account", exc_info=False)
        return subscription
