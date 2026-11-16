"""The durable register of account deletions.

Kept after an account is erased, as proof that the erasure was done (art. 5(2)
GDPR) and to apply it again if the database is ever restored from a backup that
still holds the account. It holds only a fingerprint of the account id, the
date and the reason: never an e-mail, a name, a date of birth or any content,
and no id of the person on the team who did it.

The fingerprint is a plain SHA-256 of a fixed label plus the account id, with no
secret: the id is a random UUID so it cannot be guessed back, and a key that
could be lost or rotated would make the register useless exactly when a restore
needs it. Neither the label nor the algorithm may change while the register
lives: every old row would stop matching.
"""

from __future__ import annotations

import hashlib
from datetime import datetime

from pydantic import BaseModel

DELETION_LOG_LABEL = "vetapp-deletion-log-v1:"


class DeletionReason:
    USER_NOW = "user_now"  # "Elimina subito" (the owner chose no way back)
    USER_PERIOD_END = "user_period_end"  # the period to change one's mind ended
    CLOSED_BY_AGE_USER = "closed_by_age_user"  # under the minimum age, owner's request
    CLOSED_BY_AGE_TEAM = "closed_by_age_team"  # under the minimum age, erased by the team
    SUPPORT_REQUEST = "support_request"  # asked by e-mail or through the Garante
    PAUSE_EXPIRED = "pause_expired"  # the pause ran its maximum without a sign-in
    NO_PLAN_EXPIRED = "no_plan_expired"  # the 120 days without a plan ended

    ALL = frozenset(
        {
            USER_NOW,
            USER_PERIOD_END,
            CLOSED_BY_AGE_USER,
            CLOSED_BY_AGE_TEAM,
            SUPPORT_REQUEST,
            PAUSE_EXPIRED,
            NO_PLAN_EXPIRED,
        }
    )


def owner_fingerprint(owner_id: str) -> str:
    return hashlib.sha256(f"{DELETION_LOG_LABEL}{owner_id}".encode()).hexdigest()


class DeletionLogEntry(BaseModel):
    owner_hash: str
    deleted_at: datetime
    reason: str
    # None while the erase is under way: if the process dies midway, the entry
    # stays incomplete and a re-application still treats the account as to be
    # erased.
    completed_at: datetime | None = None
