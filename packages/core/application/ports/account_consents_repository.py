from typing import Protocol

from packages.core.domain.consent.models import AccountConsents, ConsentRecord


class AccountConsentsRepository(Protocol):
    def get(self, owner_id: str) -> AccountConsents | None: ...

    def save(self, account_consents: AccountConsents) -> AccountConsents: ...

    def record(self, owner_id: str, consent_key: str, decision: ConsentRecord) -> AccountConsents:
        """Stores one decision without touching the others: two decisions sent together
        (the app sends three at sign-up) must both stay. Returns all of them."""
        ...
