"""Reading timestamps the way the live database writes them as text.

`clinical_events.created_at` is a `text` column whose default is `now()::text`, which
Postgres renders as `2026-11-22 10:11:12.123456+00`: a space instead of `T` and an offset
of two digits. Pydantic refuses that shape (it wants `+00:00`), so a single such row made
the chat of that pet fail with a 500 (collaudo K12). This turns the shapes Postgres and the
app write into the ISO form pydantic reads; anything else is returned unchanged for pydantic
to judge."""

import re

_SHAPE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})[ T]"
    r"(?P<time>\d{2}:\d{2}(?::\d{2}(?:[.,]\d{1,9})?)?)"
    r"\s*(?P<offset>Z|[+-]\d{2}(?::?\d{2})?)?$"
)


def lenient_timestamp(value: object) -> object:
    """`2026-11-22 10:11:12.5+00` -> `2026-11-22T10:11:12.5+00:00`. Not a string, or not
    this shape: unchanged."""
    if not isinstance(value, str):
        return value
    match = _SHAPE.match(value.strip())
    if match is None:
        return value
    offset = match.group("offset") or ""
    if offset and offset != "Z":
        digits = offset[1:].replace(":", "")
        offset = f"{offset[0]}{digits[:2]}:{digits[2:] or '00'}"
    time = match.group("time").replace(",", ".")
    return f"{match.group('date')}T{time}{offset}"
