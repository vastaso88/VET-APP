from typing import Protocol

from packages.core.domain.consent.models import AccountConsents


class AccountConsentsRepository(Protocol):
    def get(self, owner_id: str) -> AccountConsents | None: ...

    def save(self, account_consents: AccountConsents) -> AccountConsents: ...
