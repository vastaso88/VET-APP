from __future__ import annotations

import logging
import time
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from contextvars import ContextVar
from datetime import datetime

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.application.ports.account_consents_repository import (
    AccountConsentsRepository,
)
from packages.core.application.ports.account_deletion_repository import (
    AccountDeletionRepository,
)
from packages.core.application.ports.auth_provider import (
    AuthenticatedUser,
    AuthProvider,
    AuthSession,
)
from packages.core.application.services.account_pause import AccountPauseService
from packages.core.domain.age.models import AgeBand, band_for
from packages.core.domain.common.entity import utc_now
from packages.core.domain.consent.account_consent_text import CURRENT_VERSIONS
from packages.core.domain.consent.models import AccountConsentType
from packages.core.domain.localization import SupportedLocale
from packages.shared.errors.base import AgeRestrictedError, ConsentRequiredError

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


_allow_missing_consent: ContextVar[bool] = ContextVar("allow_missing_consent", default=False)


@contextmanager
def allow_missing_consent() -> Iterator[None]:
    """For the routes that must work before the Terms and the Privacy notice are
    accepted: the consent routes themselves, the legal texts, the export, the
    deletion and the cheap session check."""
    token = _allow_missing_consent.set(True)
    try:
        yield
    finally:
        _allow_missing_consent.reset(token)


def forget_gate_cache(provider: object, owner_id: str) -> None:
    """Drops what the guard remembers about an owner (after a consent changed)."""
    if isinstance(provider, AgeGuardedAuthProvider):
        provider.forget(owner_id)


class AgeGuardedAuthProvider(AuthProvider):
    """Wraps the real provider so that an account which declared an age under
    the minimum (403 `under_minimum_age`) or which asked to be deleted and is
    waiting for the end of its period (403 `account_deactivated`) can use
    *nothing*: every route that identifies the caller refuses, except those
    inside [allow_closed_account]. One place instead of a check per route.

    The age is looked up at most once a minute per account (the answer is
    cached per process). If the lookup fails the caller is let through: an
    outage or a table not created yet must not lock every owner out, and the
    Mercatino and paid plans check the age themselves and fail closed."""

    def __init__(
        self,
        inner: AuthProvider,
        repository: Callable[[], AccountAgeRepository],
        deletions: Callable[[], AccountDeletionRepository] | None = None,
        pauses: Callable[[], AccountPauseService] | None = None,
        consents: Callable[[], AccountConsentsRepository] | None = None,
        enforce_consent: Callable[[], bool] | None = None,
        *,
        ttl_seconds: float = 60.0,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._inner = inner
        self._repository = repository
        self._deletions = deletions
        self._pauses = pauses
        self._consents = consents
        self._enforce_consent = enforce_consent
        self._consent_missing: dict[str, tuple[bool, float]] = {}
        self._ttl = ttl_seconds
        self._clock = clock
        self._blocked: dict[str, tuple[str | None, float]] = {}

    def get_current_user(self) -> AuthenticatedUser:
        user = self._inner.get_current_user()
        if not _allow_closed_account.get():
            code = self._block_for(user.id)
            if code == "account_paused" and self._pauses is not None:
                # A paused account is usable again from the first sign-in made after
                # the pause began; the session that paused it is refused.
                if self._pauses().resume_if_signed_in_again(user.id, self._inner.last_sign_in_at()):
                    self.forget(user.id)
                    code = None
            if code is not None:
                raise AgeRestrictedError(code)
            if (
                not _allow_missing_consent.get()
                and self._enforce_consent is not None
                and self._enforce_consent()
                and self._consent_missing_for(user.id)
            ):
                raise ConsentRequiredError("consent_required")
        return user

    def _consent_missing_for(self, owner_id: str) -> bool:
        """True when the Terms or the Privacy notice are not accepted at the current
        version. Looked up at most once a minute per account; a failed lookup lets the
        caller through (an outage must not lock everybody out)."""
        if self._consents is None:
            return False
        now = self._clock()
        cached = self._consent_missing.get(owner_id)
        if cached is not None and cached[1] > now:
            return cached[0]
        try:
            record = self._consents().get(owner_id)
            given = record.consents if record is not None else {}
            missing = any(
                not (
                    key in given
                    and given[key].granted
                    and given[key].version == CURRENT_VERSIONS[key]
                )
                for key in sorted(AccountConsentType.MANDATORY)
            )
        except Exception:  # noqa: BLE001 - fail open
            logger.warning("could not read the consent gate", exc_info=False)
            return False
        self._consent_missing[owner_id] = (missing, now + self._ttl)
        return missing

    def forget(self, owner_id: str) -> None:
        """Drop the cached answer (the owner declared an age, asked to delete
        the account, or cancelled the deletion)."""
        self._blocked.pop(owner_id, None)
        self._consent_missing.pop(owner_id, None)

    def _block_for(self, owner_id: str) -> str | None:
        now = self._clock()
        cached = self._blocked.get(owner_id)
        if cached is not None and cached[1] > now:
            return cached[0]
        code: str | None = None
        try:
            record = self._repository().get(owner_id)
            if (
                record is not None
                and band_for(record.birth_date, utc_now().date()) == AgeBand.UNDER_MINIMUM
            ):
                code = "under_minimum_age"
            elif self._deletions is not None and self._deletions().get(owner_id) is not None:
                code = "account_deactivated"
            elif self._pauses is not None and self._pauses().is_paused(owner_id):
                code = "account_paused"
        except Exception:  # noqa: BLE001 - fail open, see the class docstring
            logger.warning("could not read the account gate", exc_info=False)
            return None
        self._blocked[owner_id] = (code, now + self._ttl)
        return code

    def update_preferred_locale(self, locale: SupportedLocale) -> AuthenticatedUser:
        return self._inner.update_preferred_locale(locale)

    def sign_in_with_password(self, email: str, password: str) -> AuthSession:
        return self._inner.sign_in_with_password(email, password)

    def sign_up(self, email: str, password: str) -> AuthSession | None:
        return self._inner.sign_up(email, password)

    def last_sign_in_at(self) -> datetime | None:
        return self._inner.last_sign_in_at()
