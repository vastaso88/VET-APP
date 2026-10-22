"""Store listings (docs/store/listings/*.md): length limits and honesty guards."""

from __future__ import annotations

import re
from pathlib import Path

import pytest

LISTINGS = Path(__file__).resolve().parents[2] / "docs" / "store" / "listings"
FIELD = re.compile(
    r"### (?P<label>[^\n]*?) \(max (?P<limit>\d+)\)\n\n```text\n(?P<text>.*?)\n```", re.DOTALL
)
CODES = ["it", "en-GB", "en-US", "en-AU", "de", "fr", "es"]

# Things a listing must never promise before they exist / are decided.
FORBIDDEN = [
    r"[€£$]\s?\d",
    r"\d\s?(€|£|\$|CHF|EUR|GBP|USD|AUD)",
    r"\bfree forever\b|\bgratis per sempre\b",
    r"\b(diagnos(e|is)s?)\b.*\b(your|with)\b.*\bAI\b",
    r"\b(marketplace|mercatino|marché|mercadillo|marktplatz)\b",
]


def _fields(code: str) -> list[tuple[str, int, str]]:
    text = (LISTINGS / f"{code}.md").read_text(encoding="utf-8")
    return [(m["label"], int(m["limit"]), m["text"]) for m in FIELD.finditer(text)]


def test_every_locale_has_a_listing() -> None:
    assert sorted(p.stem for p in LISTINGS.glob("*.md")) == sorted(CODES)


@pytest.mark.parametrize("code", CODES)
def test_each_field_respects_its_limit(code: str) -> None:
    fields = _fields(code)
    labels = [label for label, _, _ in fields]
    # 4 Google Play fields + 6 App Store fields.
    assert len(fields) == 10, labels
    for label, limit, text in fields:
        assert text.strip(), f"{code}: {label} is empty"
        assert len(text) <= limit, f"{code}: {label} has {len(text)} > {limit} characters"


@pytest.mark.parametrize("code", CODES)
def test_keywords_are_comma_separated_without_waste(code: str) -> None:
    keywords = next(text for label, _, text in _fields(code) if label == "Parole chiave")
    items = keywords.split(",")
    assert all(item == item.strip() and item for item in items), keywords
    assert len({item.lower() for item in items}) == len(items), "duplicate keyword"
    assert "vetapp" not in keywords.lower(), "the app name is already indexed"


@pytest.mark.parametrize("code", CODES)
def test_the_ai_and_vet_disclaimers_are_present(code: str) -> None:
    long_text = next(text for label, _, text in _fields(code) if label == "Descrizione completa")
    assert re.search(r"\bAI\b|\bIA\b|\bKI\b", long_text), f"{code}: no AI disclosure"
    # "does not replace your vet" and "emergency" must both survive translations.
    assert re.search(r"emergenc|urgenc|Notdienst|urgence|pronto soccorso", long_text, re.I), code


@pytest.mark.parametrize("code", CODES)
def test_no_prices_or_unreleased_features(code: str) -> None:
    for label, _, text in _fields(code):
        for pattern in FORBIDDEN:
            assert not re.search(pattern, text, re.I), f"{code}: {label} matches {pattern!r}"


def test_us_uses_us_words_and_uk_au_do_not() -> None:
    def long_text(code: str) -> str:
        return next(t for label, _, t in _fields(code) if label == "Descrizione completa")

    assert "veterinarian" in long_text("en-US") and "medication" in long_text("en-US")
    for code in ("en-GB", "en-AU"):
        assert "veterinarian" not in long_text(code)
        assert "medication" not in long_text(code)
