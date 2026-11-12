"""How long the data of an account without access is kept (owner decision
2026-11-08): four months, with notices that come closer and closer, then the
account is erased.

D is the day access was lost (the trial ended with no plan, or a plan was not
renewed). Notices go out on D+0, 30, 60, 90, then 14, 7, 3 and 1 days before
the erasure, which happens on D+120. Choosing a plan stops the clock;
exporting the data does not.

This module is only the calendar and the rules, with no clock of its own:
the day D is stamped on the subscription the first time the account is seen
without access (never derived from `trial_ends_at`, or the end of a public
test would find accounts whose trial ended months ago and erase them at once).
Nothing here sends or erases anything.
"""

from datetime import datetime, timedelta

RETENTION_DAYS = 120

# Days after D on which a notice is due: 14, 7, 3 and 1 days before the 120th.
NOTICE_DAYS: tuple[int, ...] = (0, 30, 60, 90, 106, 113, 117, 119)

# The last notice says "tomorrow": the erasure waits at least this long after
# it was actually sent, so a job that was switched on late (or paused) can
# never erase an account on the same run that first warns it.
LAST_NOTICE_MIN_WAIT = timedelta(hours=20)


def days_since_loss(access_lost_at: datetime, now: datetime) -> int:
    """Whole days since D (0 on the day itself, never negative)."""
    return max(0, (now - access_lost_at).days)


def data_kept_until(access_lost_at: datetime) -> datetime:
    """The instant the data is erased if nothing changes: D + 120 days."""
    return access_lost_at + timedelta(days=RETENTION_DAYS)


def due_notice_day(
    access_lost_at: datetime, now: datetime, last_notice_day: int | None
) -> int | None:
    """The notice to send now, or None.

    Only the most recent one that is due and not yet sent: a job that skipped
    days (or was switched on late) sends one message, never a burst of old
    ones."""
    elapsed = days_since_loss(access_lost_at, now)
    due = [
        day
        for day in NOTICE_DAYS
        if day <= elapsed and (last_notice_day is None or day > last_notice_day)
    ]
    return due[-1] if due else None


def past_retention(access_lost_at: datetime, now: datetime) -> bool:
    return days_since_loss(access_lost_at, now) >= RETENTION_DAYS


def erasure_allowed(
    access_lost_at: datetime,
    now: datetime,
    *,
    last_notice_day: int | None,
    last_notice_at: datetime | None,
) -> bool:
    """True only when the 120 days are over AND the "tomorrow" notice was sent
    at least [LAST_NOTICE_MIN_WAIT] ago. An account that was never warned is
    never erased, whatever its age."""
    if not past_retention(access_lost_at, now):
        return False
    if last_notice_day != NOTICE_DAYS[-1] or last_notice_at is None:
        return False
    return now - last_notice_at >= LAST_NOTICE_MIN_WAIT
