"""Conversation titles.

Until 2026-10-06 every conversation was called "Chat for {pet_id}" — in
English, with an internal identifier, shown at the top of the chat. A
title is now derived from the owner's first message by a small heuristic
(no model call: it has to be instant and cost nothing), and the owner can
rename it.
"""

from __future__ import annotations

import re

LEGACY_TITLE_PREFIX = "Chat for "
MAX_TITLE_CHARS = 40
MAX_CUSTOM_TITLE_CHARS = 60
DEFAULT_TITLE = "Nuova conversazione"

# Openers that carry no topic: dropped from the start of the message,
# repeatedly, until a word of substance is reached.
_FILLER_OPENERS = (
    r"ciao",
    r"buongiorno",
    r"buonasera",
    r"salve",
    r"hey",
    r"scusa(mi)?",
    r"senti",
    r"una domanda",
    r"ho una domanda",
    r"avrei una domanda",
    r"volevo (sapere|chiedere|chiederti)",
    r"vorrei (sapere|chiedere|chiederti|capire)",
    r"mi (spieghi|dici|sai dire|puoi dire)",
    r"puoi (spiegarmi|dirmi|aiutarmi)",
    r"spiegami",
    r"dimmi",
    r"secondo te",
    r"per favore",
    r"è vero che",
    r"e vero che",
    r"è normale che",
    r"e normale che",
    r"come mai",
    r"perch[eé]",
    r"cosa (significa|vuol dire|succede)",
    r"che (cos'è|cosa è|significa|vuol dire)",
    r"cos'è",
)
_FILLER = re.compile(r"^(?:" + "|".join(_FILLER_OPENERS) + r")\b[\s,:.!]*", re.IGNORECASE)
_WHITESPACE = re.compile(r"\s+")
_CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def is_legacy_title(title: str) -> bool:
    return title.startswith(LEGACY_TITLE_PREFIX) or not title.strip()


def title_from_message(message: str) -> str:
    """A short Italian title with the topic of the owner's first message,
    e.g. "spiegami il referto degli esami del sangue?" -> "Il referto degli
    esami del sangue"; "lo sbadiglio può essere un problema?" -> "Lo
    sbadiglio può essere un problema"."""
    text = _strip_fillers(_WHITESPACE.sub(" ", message).strip())
    # The first sentence or clause left is the topic.
    text = _strip_fillers(re.split(r"[?!.\n;]", text, maxsplit=1)[0].strip())
    if not text:
        text = _WHITESPACE.sub(" ", message).strip(" ?!.,:")
    if not text:
        return DEFAULT_TITLE
    text = text[0].upper() + text[1:]
    return _truncate(text, MAX_TITLE_CHARS)


def _strip_fillers(text: str) -> str:
    previous = None
    while previous != text:
        previous = text
        text = _FILLER.sub("", text).strip(" ,:!")
    return text


def clean_custom_title(title: str) -> str:
    """The owner's own title, tidied: whitespace collapsed, control
    characters removed, length capped. Raises ValueError when nothing is
    left."""
    text = _WHITESPACE.sub(" ", _CONTROL.sub(" ", title)).strip()
    if not text:
        raise ValueError("title must not be empty")
    return _truncate(text, MAX_CUSTOM_TITLE_CHARS)


def _truncate(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    cut = text[: limit - 1]
    if " " in cut[limit // 2 :]:
        cut = cut[: cut.rfind(" ")]
    return cut.rstrip(" ,;:") + "…"
