"""Calendar of a pause (docs/compliance/18 §4): service e-mails only, never commercial.

A pause lasts until the owner signs in again, up to [max_months] without
access; then the account is erased. The e-mails: P1 at the start, P3 once a
year (not within the last 30 days), P4 a month before the erasure, P5 seven
days before, P6 the day before. The silence of the owner can only shorten the
keeping, never lengthen it.

Nothing here sends or erases anything and nothing reads a clock. The same
rules as the other calendars: only the most recent notice that is due and not
yet sent goes out, never a burst, and an account is erased only after the
"tomorrow" notice was recorded at least [LAST_NOTICE_MIN_WAIT] ago.
"""

from __future__ import annotations

import calendar
from datetime import datetime, timedelta

START = "P1"
ANNUAL_PREFIX = "P3-"  # P3-1 after a year, P3-2 after two, ...
MONTH_LEFT = "P4"
WEEK_LEFT = "P5"
DAY_LEFT = "P6"

LAST_NOTICE_MIN_WAIT = timedelta(hours=20)


def add_months(moment: datetime, months: int) -> datetime:
    """The same day [months] later (the last day of the month if it has none)."""
    index = moment.month - 1 + months
    year = moment.year + index // 12
    month = index % 12 + 1
    day = min(moment.day, calendar.monthrange(year, month)[1])
    return moment.replace(year=year, month=month, day=day)


def delete_after(paused_at: datetime, max_months: int) -> datetime:
    """The day the account is erased if the owner never signs in."""
    return add_months(paused_at, max_months)


def schedule(paused_at: datetime, max_months: int) -> list[tuple[str, datetime]]:
    """Every notice of the pause with the moment it is due, in order."""
    end = delete_after(paused_at, max_months)
    month_before = end - timedelta(days=30)
    items: list[tuple[str, datetime]] = [(START, paused_at)]
    year = 1
    while (moment := add_months(paused_at, 12 * year)) < month_before:
        items.append((f"{ANNUAL_PREFIX}{year}", moment))
        year += 1
    items += [
        (MONTH_LEFT, month_before),
        (WEEK_LEFT, end - timedelta(days=7)),
        (DAY_LEFT, end - timedelta(days=1)),
    ]
    return items


def due_notice(
    paused_at: datetime, max_months: int, now: datetime, last_sent: str | None
) -> str | None:
    """The notice to send now, or None. [last_sent] is the last one already sent."""
    items = schedule(paused_at, max_months)
    names = [name for name, _ in items]
    sent_index = names.index(last_sent) if last_sent in names else -1
    due = [
        name for index, (name, moment) in enumerate(items) if moment <= now and index > sent_index
    ]
    return due[-1] if due else None


def erasure_allowed(
    paused_at: datetime,
    max_months: int,
    now: datetime,
    *,
    last_notice: str | None,
    last_notice_at: datetime | None,
) -> bool:
    """True only when the period is over AND the "tomorrow" notice was sent at
    least [LAST_NOTICE_MIN_WAIT] ago. A pause that was never warned is never
    erased, whatever its age."""
    if now < delete_after(paused_at, max_months):
        return False
    if last_notice != DAY_LEFT or last_notice_at is None:
        return False
    return now - last_notice_at >= LAST_NOTICE_MIN_WAIT
