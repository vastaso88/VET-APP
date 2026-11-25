"""Deletion with a period to change one's mind.

When an owner deletes their account it is deactivated at once (nothing of it is
visible or usable, its data is frozen) and erased for good when the period ends.
Until then they can come back with the same e-mail (resetting the password
through the e-mail link if needed) and cancel the deletion. The length of the
period is a setting (ACCOUNT_DELETION_GRACE_DAYS), never a number in the code.
"""

from datetime import datetime

from pydantic import BaseModel


class AccountDeletionRequest(BaseModel):
    owner_id: str
    requested_at: datetime
    # The moment from which the account may be erased for good.
    purge_after: datetime
    # The last e-mail notice of the sequence already sent (docs/compliance/18 §5), or None.
    last_notice: str | None = None
    # When that notice was booked (just before sending): the erasure waits 20 hours from it.
    last_notice_at: datetime | None = None
