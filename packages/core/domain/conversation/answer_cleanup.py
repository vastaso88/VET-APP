"""Last pass on a reply before it leaves the backend (wide eval 2026-11-06).

The chat API and the app send and show no source list, so a reply must
not point to one: numbered markers ("[1]") and promises such as "ti
lascio le fonti" are removed. Also mends the punctuation left by the
evidence synthesis (";.", a capital after a connector).
"""

from __future__ import annotations

import re

_MARKER = re.compile(r"\s?\[\d+(?:,\s?\d+)*\]")
_PROMISE = re.compile(
    r"[^.!?\n]*\b(?:ti lascio (?:anche |qui )?(?:le |qualche |alcune )?font[ei]|trovi le fonti|"
    r"le fonti (?:le trovi |sono )?(?:qui sotto|in fondo|in calce|elencate)|vedi (?:le )?fonti|"
    r"fonti (?:qui )?sotto|come da fonti|"
    r"i(?:'ll| will) leave (?:you )?the sources|sources (?:are )?(?:below|listed)|"
    r"see (?:the )?sources|"
    r"te dejo las fuentes|fuentes (?:abajo|al final)|"
    r"quellen (?:unten|am ende)|ich lasse (?:dir|ihnen) die quellen|"
    r"je (?:vous|te) laisse les sources|sources ci-dessous)\b[^.!?\n]*[.!?]?",
    re.IGNORECASE,
)
_SEMICOLON_DOT = re.compile(r"\s*;\s*\.")
_SPACED_PUNCT = re.compile(r"\s+([.,;:!?])")
_DOUBLE_SPACE = re.compile(r"[ \t]{2,}")


def clean_answer_text(text: str) -> str:
    cleaned = _MARKER.sub("", text)
    cleaned = _PROMISE.sub("", cleaned)
    cleaned = _SEMICOLON_DOT.sub(".", cleaned)
    cleaned = _SPACED_PUNCT.sub(r"\1", cleaned)
    cleaned = _DOUBLE_SPACE.sub(" ", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned).strip()
    return cleaned or text
