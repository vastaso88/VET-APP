"""The pause: an account its owner put aside, with no deletion asked.

Different from "Elimina": nothing is erased and nothing is scheduled. The
account is inactive (hidden, no sign-in on the old session, no messages other
than the service ones of docs/auth/02) and its data is kept. The owner comes
back by signing in again, which ends the pause. A long cap (PAUSE_MAX_MONTHS)
may be set by the legal opinion; it is a setting, never a number in the code.
"""

from datetime import datetime

from pydantic import BaseModel


class AccountPause(BaseModel):
    owner_id: str
    paused_at: datetime
    # The last service e-mail of the pause sequence already sent, and when.
    last_notice: str | None = None
    last_notice_at: datetime | None = None
    # Set when the owner signed in again: the pause is over, but the row stays
    # until the app has shown "the pause is over" (docs/compliance/18 §3.2).
    resumed_at: datetime | None = None

    @property
    def active(self) -> bool:
        return self.resumed_at is None
