"""When a notice still says what is true (docs/compliance/18 §8.9, «Avvisi in ritardo»).

Some texts speak in relative terms: «mancano 7 giorni», «domani», «manca un mese». A notice that
goes out late (the scheduler was off, the provider was down) must not say «domani» about a date
that is already past or still far away. Three things protect the reader:

- the date in the text is the TRUE day the erasure job will run after the date has come (the job
  runs hourly, at a fixed minute: a request made just before midnight is erased the day after);
  for the last warning that moment is never less than 20 hours after the sending (the same 20
  hours the erasure waits for), so a late warning moves the date, never the promise;
- the normal text is used only when, on the day of sending, EXACTLY 7 calendar days (D2)
  or 1 day (D3) separate that day from the erasure day; otherwise the
  «late» text goes out, which says only the true date;
- for the final notice of «Elimina» that moment is also at least 20 hours after the sending,
  so a notice that goes after the day moves the date, and D_LATE goes out on any day.
"""

from __future__ import annotations

from datetime import datetime, timedelta

# The least time between the last warning and the erasure.
MIN_GAP_AFTER_LAST_WARNING = timedelta(hours=20)

# Dates are UTC, like the rest of the backend, with no time-zone library. In Italy (UTC+1/+2) the
# local day is always the same as or later than the UTC day, so nothing is ever erased before the
# date written in the e-mail. For people west of UTC (the Americas) the erasure can fall a few
# hours before their local day: a limit to close with the translations, not now.

# The erasure jobs run every hour at this minute (`cron: "17 * * * *"` in
# .github/workflows/admin-scheduler.yml). Keep the two together.
JOB_MINUTE = 17

# Template -> the whole calendar days that may separate the day of sending from the day of the
# erasure for its relative words to be true. A text not listed here has no relative words.
_TRUE_WHEN_DAYS_LEFT: dict[str, range] = {
    "D2": range(7, 8),  # «mancano 7 giorni»
    "D3": range(1, 2),  # «domani»
}
_LATE_VERSION = {"D2": "D_LATE", "D3": "D_LATE"}


# The last warning of each sequence: the erasure waits 20 hours from it.
_LAST_WARNING = frozenset({"D3"})


def job_run_after(moment: datetime) -> datetime:
    """The first moment at or after [moment] when the erasure job runs."""
    run = moment.replace(minute=JOB_MINUTE, second=0, microsecond=0)
    if run < moment:
        run += timedelta(hours=1)
    return run


def days_left(now: datetime, erasure: datetime) -> int:
    """Whole calendar days from the day of sending to the day of the erasure."""
    return (erasure.date() - now.date()).days


def effective_erasure(planned: datetime, now: datetime, template_id: str) -> datetime:
    """The moment the erasure can really happen, whose DAY the text states. For the last warning
    it is at least [MIN_GAP_AFTER_LAST_WARNING] after the sending, so a warning that
    goes late postpones the date instead of promising one that is gone. Always the first run of
    the hourly job at or after that moment."""
    moment = planned
    if template_id in _LAST_WARNING:
        moment = max(planned, now + MIN_GAP_AFTER_LAST_WARNING)
    return job_run_after(moment)


def template_for_moment(template_id: str, now: datetime, erasure: datetime) -> str:
    """[template_id] when its relative words are still true, else the plain-date «late» text
    (D_LATE also goes out after the day of the erasure: the erasure waited for it).
    [erasure] is the REAL moment, see above."""
    allowed = _TRUE_WHEN_DAYS_LEFT.get(template_id)
    left = days_left(now, erasure)
    if allowed is None or left in allowed:
        return template_id
    return _LATE_VERSION[template_id]
