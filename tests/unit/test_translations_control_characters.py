"""A search-and-replace on the translations once left a control character where French
punctuation was (2026-11-23): no text may hold one."""

import json
import unicodedata
from pathlib import Path

import pytest

from packages.core.domain.localization import _MESSAGES

L10N = Path(__file__).resolve().parents[2] / "apps" / "mobile_app" / "lib" / "l10n"


def _controls(text: str) -> bool:
    return any(unicodedata.category(char) == "Cc" and char != "\n" for char in text)


@pytest.mark.parametrize("language", ["it", "en", "es", "de", "fr"])
def test_no_control_characters_in_the_texts(language: str) -> None:
    arb = json.loads((L10N / f"app_{language}.arb").read_text(encoding="utf-8"))
    bad = [key for key, value in arb.items() if isinstance(value, str) and _controls(value)]
    bad += [
        key
        for key, texts in _MESSAGES.items()
        if any(code == language and _controls(text) for code, text in texts.items())
    ]

    assert bad == []
