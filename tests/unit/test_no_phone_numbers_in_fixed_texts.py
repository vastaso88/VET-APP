"""Owner's decision (21/11/2026): «l'app non gestisce urgenze». No phone number in any fixed
text, in any language, for any country (no listening line, no 112/118/999/911), and none in
the notes and prompts the model reads (Normativa: a note with a number contradicts the rule
"never write a phone number"). The net that strips numbers written by the model stays."""

from __future__ import annotations

import importlib
import re
from collections.abc import Iterator
from typing import Any

import pytest

from packages.core.domain.knowledge.answer_validation import has_phone_number

# Modules whose constants are fixed texts the owner reads, or notes and prompts the model reads.
MODULES = (
    "packages.core.domain.safety.harmful_requests",
    "packages.core.domain.safety.first_aid",
    "packages.core.domain.safety.clarification_fit",
    "packages.core.domain.safety.triage_clarification",
    "packages.core.domain.safety.human_drug_toxicity",
    "packages.core.domain.localization",
    "packages.core.domain.localization_fr",
    "packages.core.domain.knowledge.duty_notes",
    "packages.core.application.services.natural_answer_prompt",
    "packages.core.application.services.urgency_classifier",
)
# Helpline and emergency numbers that were once in these texts, and any number in brackets
# written like a phone number ("(1515)"), on top of the model net's own patterns.
_KNOWN = re.compile(
    r"02 2327 2327|19696|116 ?123|1515|3114|0800[ \d]{5,}|13 11 14|1737|1813|9-8-8|9-1-1|"
    r"\(\s*\d{3,6}\s*\)"
)


def _strings(value: Any, seen: set[int]) -> Iterator[str]:
    if id(value) in seen:
        return
    seen.add(id(value))
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _strings(item, seen)
    elif isinstance(value, (list, tuple, set, frozenset)):
        for item in value:
            yield from _strings(item, seen)
    elif hasattr(value, "snippet") and isinstance(value.snippet, str):  # duty notes
        yield value.snippet


def _texts() -> Iterator[tuple[str, str]]:
    for name in MODULES:
        module = importlib.import_module(name)
        for attr, value in vars(module).items():
            if attr.startswith("__") or isinstance(value, re.Pattern) or callable(value):
                continue
            for text in _strings(value, set()):
                if len(text) > 20 and " " in text:  # sentences, not codes or keys
                    yield f"{name}.{attr}", text


@pytest.mark.parametrize("module", MODULES)
def test_no_fixed_text_or_model_note_carries_a_phone_number(module: str) -> None:
    offenders = [
        f"{where}: {text[:90]}"
        for where, text in _texts()
        if where.startswith(module) and (has_phone_number(text) or _KNOWN.search(text))
    ]
    assert not offenders, "\n".join(offenders)


def test_the_scan_finds_numbers() -> None:
    assert has_phone_number("chiama subito il 112.")
    assert _KNOWN.search("Telefono Amico Italia, 02 2327 2327")
    assert _KNOWN.search("i Carabinieri forestali (1515)")
    assert not _KNOWN.search("legge 157/1992, fino a 18 anni")
