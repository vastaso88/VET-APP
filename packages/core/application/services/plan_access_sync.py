"""Keeps the database's copy of three backend-only facts in line with the backend:
the public-test plan, the developer allowlist and the cap on pets in Ricordi
(see PlanAccessStore). Called
at each subscription status check, the moment the app asks "what may I do".

Built once per process (application container), so it remembers what it last
wrote and does not repeat the same write at every check. Best effort: the
tables may not exist yet (scripts/setup/plan_access_rules.sql not run), and
this bookkeeping must never decide the owner's own answer, so a failure is
logged and forgotten (the next check tries again)."""

import logging
import threading

from packages.core.application.ports.plan_access_store import PlanAccessStore

logger = logging.getLogger(__name__)

_UNSET = object()


class PlanAccessSync:
    def __init__(self, store: PlanAccessStore) -> None:
        self._store = store
        self._lock = threading.Lock()
        self._test_plan: object = _UNSET
        self._max_memorial_pets: int | None = None
        self._unlimited: dict[str, bool] = {}

    def sync(
        self,
        *,
        owner_id: str,
        is_developer: bool,
        test_plan: str | None,
        max_memorial_pets: int | None = None,
    ) -> None:
        self._sync_test_plan(test_plan)
        if max_memorial_pets is not None:
            self._sync_max_memorial_pets(max_memorial_pets)
        self._sync_unlimited(owner_id, is_developer)

    def _sync_test_plan(self, test_plan: str | None) -> None:
        with self._lock:
            if self._test_plan == test_plan:
                return
        try:
            self._store.set_test_plan(test_plan)
        except Exception:  # noqa: BLE001 - bookkeeping, never the owner's answer
            logger.warning("could not write the test plan for the database rules")
            return
        with self._lock:
            self._test_plan = test_plan

    def _sync_max_memorial_pets(self, cap: int) -> None:
        with self._lock:
            if self._max_memorial_pets == cap:
                return
        try:
            self._store.set_max_memorial_pets(cap)
        except Exception:  # noqa: BLE001 - bookkeeping, never the owner's answer
            # The column does not exist until plan_access_rules.sql is run again;
            # the database then keeps the default the script seeded.
            logger.warning("could not write the cap on pets in Ricordi for the database rules")
            return
        with self._lock:
            self._max_memorial_pets = cap

    def _sync_unlimited(self, owner_id: str, is_developer: bool) -> None:
        with self._lock:
            if self._unlimited.get(owner_id) == is_developer:
                return
        try:
            self._store.set_unlimited(owner_id, is_developer)
        except Exception:  # noqa: BLE001 - bookkeeping, never the owner's answer
            logger.warning("could not write an account's plan exemption for the database rules")
            return
        with self._lock:
            # Bounded: one entry per account seen by this process.
            if len(self._unlimited) > 50_000:
                self._unlimited.clear()
            self._unlimited[owner_id] = is_developer
