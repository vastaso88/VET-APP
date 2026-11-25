"""The e-mails around "Elimina l'account" (service messages, no offers).

Calendar for someone who pressed "Elimina": a confirmation at once (with the
way back), a reminder a week before the erasure, a last one the day before, and
a closing message once the data is gone. All four are service messages about a
request the owner made: they carry no offer and no invitation to stay (docs/auth/02).

Nothing here sends anything or reads a clock. Times are relative to
`purge_after`, the real day of the erasure, so a changed grace period moves them
with it. The same rule as the 120-day notices (retention.py) applies: only the
most recent notice that is due and not yet sent goes out, never a burst of old ones.
"""

from __future__ import annotations

from datetime import datetime, timedelta

CONFIRMED = "confirmed"  # at once: what was asked, the date, how to go back
WEEK_LEFT = "week_left"  # 7 days before the erasure
TOMORROW = "tomorrow"  # the day before
ERASED = "erased"  # sent by the purge itself, after the data is gone

# Order of the notices sent while the request is waiting.
WAITING_SEQUENCE: tuple[str, ...] = (CONFIRMED, WEEK_LEFT, TOMORROW)

_LEAD = {WEEK_LEFT: timedelta(days=7), TOMORROW: timedelta(days=1)}

# After the day the erasure is due, how long it may still wait for the final notice to be
# registered, when the notice did not go out because of OUR fault (the sender is down, a
# password expired, a daily limit). Then the system erases by itself, writes why in the
# register and tells the team. ONE place for the number; a proposal of the Normativa
# (23 November) waiting for the owner's yes and the lawyer (docs/compliance/18 §8).
MAX_WAIT_AFTER_DUE = timedelta(days=7)


def final_notice(requested_at: datetime, purge_after: datetime) -> str:
    """The last notice of the sequence that exists for this request: «tomorrow», or the
    confirmation when the period was too short for any other."""
    return TOMORROW if purge_after - _LEAD[TOMORROW] > requested_at else CONFIRMED


def due_waiting_notice(
    requested_at: datetime,
    purge_after: datetime,
    now: datetime,
    last_sent: str | None,
) -> str | None:
    """The notice to send now, or None. [last_sent] is the last one already
    sent for this request (None if none). A notice whose moment falls on or
    before the request itself (a short grace period) is skipped, since the
    confirmation already says the date."""
    candidates = [CONFIRMED]
    for kind in (WEEK_LEFT, TOMORROW):
        moment = purge_after - _LEAD[kind]
        if moment > requested_at:
            candidates.append(kind)
    due = [
        kind
        for kind in candidates
        if (kind == CONFIRMED or now >= purge_after - _LEAD[kind])
        and (last_sent is None or WAITING_SEQUENCE.index(kind) > WAITING_SEQUENCE.index(last_sent))
    ]
    return due[-1] if due else None
