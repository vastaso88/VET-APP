"""Bounded cache for pricing plan limits, shared by the API's service container.

Only the service-role backend can fetch these rows. No client request can select
its own feature flags. New settings take effect across warm instances in <=15s.
"""
from __future__ import annotations

import logging
import threading
import time

from packages.core.domain.subscription.limits import LIMITS_BY_PLAN, PlanLimits
from packages.core.domain.subscription.pricing import configured_plan_limits
from packages.shared.config.settings import Settings

logger = logging.getLogger(__name__)

_CLOSED = {
    name: PlanLimits(
        max_pets=0, max_chats_per_pet=0, daily_questions=0,
        max_devices=0, daily_sonnet_answers=0, source=name,
    )
    for name in LIMITS_BY_PLAN
}


class PricingLimitsCache:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._lock = threading.Lock()
        self._next_fetch = 0.0
        self._last_good: dict[str, PlanLimits] | None = None
        self._migration_pending = False

    def load(self) -> dict[str, PlanLimits]:
        if self._settings.persistence_backend != "supabase":
            return LIMITS_BY_PLAN
        with self._lock:
            now = time.monotonic()
            if now < self._next_fetch:
                if self._last_good is not None:
                    return self._last_good
                return LIMITS_BY_PLAN if self._migration_pending else _CLOSED

            self._next_fetch = now + 15
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )

                response = (
                    build_supabase_client(self._settings)
                    .table("pricing_plan_features")
                    .select("plan,feature,enabled,quota")
                    .execute()
                )
                rows = response.data or []
                if len(rows) != 15:
                    raise ValueError("Incomplete pricing feature catalogue")
                loaded = configured_plan_limits(rows)
            except Exception as exc:  # noqa: BLE001 - defensive entitlement fallback
                message = str(exc)
                # Deploy the migration before turning this feature on. On
                # older databases preserve the existing published plan limits.
                if "PGRST205" in message or "42P01" in message:
                    self._migration_pending = True
                    return LIMITS_BY_PLAN
                logger.warning("Pricing entitlements unavailable; using conservative limits")
                return self._last_good if self._last_good is not None else _CLOSED

            self._migration_pending = False
            self._last_good = loaded
            return loaded
