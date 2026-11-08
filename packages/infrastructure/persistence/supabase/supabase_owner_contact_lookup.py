from __future__ import annotations

import logging
from datetime import date
from typing import TYPE_CHECKING

from packages.core.application.ports.owner_contact_lookup import OwnerContact, OwnerContactLookup

if TYPE_CHECKING:
    from supabase import Client

logger = logging.getLogger(__name__)


class SupabaseOwnerContactLookup(OwnerContactLookup):
    """Reads the e-mail of an account from Supabase Auth with the service-role
    key. Only whether an address exists and is confirmed leaves this class's
    callers' decisions; the address itself is never logged."""

    def __init__(self, client: Client) -> None:
        self._client = client

    def get(self, owner_id: str) -> OwnerContact | None:
        try:
            response = self._client.auth.admin.get_user_by_id(owner_id)
        except Exception:  # noqa: BLE001 - an outage must not look like "no address"
            logger.warning("could not read the contact of an account", exc_info=False)
            return None
        user = getattr(response, "user", None)
        if user is None:
            return None
        email = getattr(user, "email", None)
        return OwnerContact(
            email=email if isinstance(email, str) and email.strip() else None,
            email_confirmed=getattr(user, "email_confirmed_at", None) is not None,
            birth_date=self._declared_birth_date(owner_id),
        )

    def _declared_birth_date(self, owner_id: str) -> date | None:
        """From the backend's own `account_age` table. Never from the account's
        `user_metadata`: the owner can edit that themselves, so a date read
        there could be made up. No row, or a failed read, means "not known"."""
        try:
            rows = (
                self._client.table("account_age")
                .select("birth_date")
                .eq("owner_id", owner_id)
                .limit(1)
                .execute()
                .data
            )
        except Exception:  # noqa: BLE001 - unknown, not "adult"
            logger.warning("could not read the declared age", exc_info=False)
            return None
        if not rows or not isinstance(rows[0], dict):
            return None
        raw = rows[0].get("birth_date")
        if not isinstance(raw, str):
            return None
        try:
            return date.fromisoformat(raw[:10])
        except ValueError:
            return None
