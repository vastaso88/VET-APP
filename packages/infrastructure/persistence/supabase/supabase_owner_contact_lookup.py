from __future__ import annotations

import logging
from datetime import date
from typing import TYPE_CHECKING

from packages.core.application.ports.owner_contact_lookup import OwnerContact, OwnerContactLookup

if TYPE_CHECKING:
    from supabase import Client

logger = logging.getLogger(__name__)

# Where the registration is to write the declared date of birth (ISO date, in
# the account's user metadata). Nothing writes it yet: until then every
# account reads as "age not known".
BIRTH_DATE_METADATA_KEY = "birth_date"


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
            birth_date=_declared_birth_date(getattr(user, "user_metadata", None)),
        )


def _declared_birth_date(metadata: object) -> date | None:
    if not isinstance(metadata, dict):
        return None
    raw = metadata.get(BIRTH_DATE_METADATA_KEY)
    if not isinstance(raw, str):
        return None
    try:
        return date.fromisoformat(raw[:10])
    except ValueError:
        return None
