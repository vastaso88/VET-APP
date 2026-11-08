from __future__ import annotations

import logging
import time
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from contextvars import ContextVar
from datetime import datetime

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.application.ports.auth_provider import (
    AuthenticatedUser,
    AuthProvider,
    AuthSession,
)
from packages.core.domain.age.models import AgeBand, band_for
from packages.core.domain.common.entity import utc_now
from packages.core.domain.localization import SupportedLocale
from packages.shared.errors.base import AgeRestrictedError

logger = logging.getLogger(__name__)

_allow_closed_account: ContextVar[bool] = ContextVar("allow_closed_account", default=False)


@contextmanager
def allow_closed_account() -> Iterator[None]:
    """For the few routes a closed account may still use: reading its own age
    status and deleting itself."""
    token = _allow_closed_account.set(True)
    try:
        yield
    finally:
        _allow_closed_account.reset(token)


class AgeGuardedAuthProvider(AuthProvider):
    """Wraps the real provider so that an account which declared an age under
    the minimum can use *nothing*: every route that identifies the caller
    answers 403 `under_minimum_age`, except those inside
    [allow_closed_account]. One place instead of a check per route.

    The age is looked up at most once a minute per account (the answer is
    cached per process). If the lookup fails the caller is let through: an
    outage or a table not created yet must not lock every owner out, and the
    Mercatino and paid plans check the age themselves and fail closed."""

    def __init__(
        self,
        inner: AuthProvider,
        repository: Callable[[], AccountAgeRepository],
        *,
        ttl_seconds: float = 60.0,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._inner = inner
        self._repository = repository
        self._ttl = ttl_seconds
        self._clock = clock
        self._closed: dict[str, tuple[bool, float]] = {}

    def get_current_user(self) -> AuthenticatedUser:
        user = self._inner.get_current_user()
        if not _allow_closed_account.get() and self._is_closed(user.id):
            raise AgeRestrictedError("under_minimum_age")
        return user

    def forget(self, owner_id: str) -> None:
        """Drop the cached answer (the owner has just declared an age)."""
        self._closed.pop(owner_id, None)

    def _is_closed(self, owner_id: str) -> bool:
        now = self._clock()
        cached = self._closed.get(owner_id)
        if cached is not None and cached[1] > now:
            return cached[0]
        try:
            record = self._repository().get(owner_id)
        except Exception:  # noqa: BLE001 - fail open, see the class docstring
            logger.warning("could not read the age gate", exc_info=False)
            return False
        closed = (
            record is not None
            and band_for(record.birth_date, utc_now().date()) == AgeBand.UNDER_MINIMUM
        )
        self._closed[owner_id] = (closed, now + self._ttl)
        return closed

    def update_preferred_locale(self, locale: SupportedLocale) -> AuthenticatedUser:
        return self._inner.update_preferred_locale(locale)

    def sign_in_with_password(self, email: str, password: str) -> AuthSession:
        return self._inner.sign_in_with_password(email, password)

    def sign_up(self, email: str, password: str) -> AuthSession | None:
        return self._inner.sign_up(email, password)

    def last_sign_in_at(self) -> datetime | None:
        return self._inner.last_sign_in_at()
