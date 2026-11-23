"""What the API says when a request body does not fit its schema (collaudo K08).

FastAPI's own answer to a refused body is a list of English technical entries
("String should have at most 80 characters") that also carries back the very text the owner typed
(`input`). Here every entry keeps the two things the app already reads, `type` and `loc` (the chat
tells "message too long" by `string_too_long` + `user_message`), gets a short sentence in the
owner's language as `msg`, and loses everything else: the typed text never travels back, not in
the sentence, not in `input`, not in the context.

The status stays 422 and `detail` stays a list: installed apps depend on both."""

from __future__ import annotations

from collections.abc import Sequence
from typing import Any

from packages.core.domain.localization import translate

_DATE_TYPES = {"date_parsing", "date_type", "date_from_datetime_parsing", "datetime_parsing"}
_DATE_PREFIXES = ("date_", "datetime_", "time_")

# Longest piece of a field path kept: a key typed by the client must not travel back either.
_MAX_LOC_PART = 64


def _number(context: dict[str, Any], *names: str) -> object:
    for name in names:
        if name in context:
            return context[name]
    return ""


def _bound(value: object, shift: int = 0) -> object:
    """An exclusive limit (`lt`, `gt`) shown as the nearest value that is allowed."""
    return value + shift if isinstance(value, int) and not isinstance(value, bool) else value


def request_error_message(error: dict[str, Any], language: str) -> str:
    """One short sentence for one entry of FastAPI's error list. Never contains the input."""
    kind = str(error.get("type", ""))
    context = error.get("ctx") or {}
    if kind == "string_too_long":
        return translate("input_too_long", language, max=_number(context, "max_length"))
    if kind == "string_too_short":
        return translate("input_too_short", language, min=_number(context, "min_length"))
    if kind == "too_long":
        return translate("input_too_many_items", language, max=_number(context, "max_length"))
    if kind in {"less_than", "less_than_equal"}:
        limit = (
            _number(context, "le")
            if kind == "less_than_equal"
            else _bound(_number(context, "lt"), -1)
        )
        return translate("input_number_too_large", language, max=limit)
    if kind in {"greater_than", "greater_than_equal"}:
        limit = (
            _number(context, "ge")
            if kind == "greater_than_equal"
            else _bound(_number(context, "gt"), 1)
        )
        return translate("input_number_too_small", language, min=limit)
    if kind == "missing":
        return translate("input_missing", language)
    if kind in _DATE_TYPES or kind.startswith(_DATE_PREFIXES):
        return translate("input_bad_date", language)
    return translate("input_invalid", language)


def request_error_body(errors: Sequence[Any], language: str) -> dict[str, Any]:
    """The 422 body: the list the apps read (`type`, `loc`), a sentence per entry, a stable
    `code`, and the first sentence as `message` for any client that shows one text."""
    entries: list[dict[str, Any]] = []
    for raw in errors:
        error = raw if isinstance(raw, dict) else {}
        loc = [
            part if isinstance(part, int) else str(part)[:_MAX_LOC_PART]
            for part in error.get("loc", ())
        ]
        entries.append(
            {
                "type": str(error.get("type", "value_error")),
                "loc": loc,
                "msg": request_error_message(error, language),
            }
        )
    message = entries[0]["msg"] if entries else translate("input_invalid", language)
    return {"detail": entries, "code": "invalid_input", "message": message}
