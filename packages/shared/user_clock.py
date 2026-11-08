"""The owner's local clock, as the app reports it.

The app sends the phone's current offset from UTC (`X-UTC-Offset-Minutes`,
e.g. 60 in winter and 120 in summer for Rome). The backend needs it for one
thing: the per-owner daily counters (questions, photos, dictations, summaries)
start over at the owner's own midnight, not at midnight UTC.

An offset is enough: nothing here needs the zone's rules, because the phone
sends the offset that holds now, summer time included. It also needs no time
zone database on the server.

Whatever the header carries is only trusted as far as this module checks it:
a whole number of minutes, a multiple of 15, between UTC-12:00 and UTC+14:00.
Anything else (missing, malformed, out of range) means UTC, the behaviour
before the offset existed. Old app builds send nothing and keep it.
"""

import re
from contextvars import ContextVar, Token

MIN_OFFSET_MINUTES = -12 * 60
MAX_OFFSET_MINUTES = 14 * 60
# ASCII digits only: `\d` and int() also accept other scripts' digits.
_PATTERN = re.compile(r"[+-]?[0-9]{1,4}")

_utc_offset_minutes: ContextVar[int] = ContextVar("utc_offset_minutes", default=0)


def parse_utc_offset_minutes(raw: str | None) -> int:
    """The offset the header says, or 0 (UTC) when it is not a believable one."""
    if raw is None:
        return 0
    text = raw.strip()
    if not _PATTERN.fullmatch(text):
        return 0
    minutes = int(text)
    if minutes % 15 != 0 or not MIN_OFFSET_MINUTES <= minutes <= MAX_OFFSET_MINUTES:
        return 0
    return minutes


def current_utc_offset_minutes() -> int:
    """The offset of the request being served; 0 outside a request."""
    return _utc_offset_minutes.get()


def set_utc_offset_minutes(minutes: int) -> Token[int]:
    return _utc_offset_minutes.set(minutes)


def reset_utc_offset_minutes(token: Token[int]) -> None:
    _utc_offset_minutes.reset(token)
