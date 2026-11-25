"""The text of the Mercatino's messages: what nobody can see goes, what everybody sees
stays; contacts and codes are recognised, dates and prices are not."""

from __future__ import annotations

import json
import time
from pathlib import Path

import pytest

from packages.core.domain.marketplace.message_text import clean_message_text, needs_caution

CASES = json.loads(
    (Path(__file__).parents[1] / "fixtures/marketplace_message_caution_cases.json").read_text(
        encoding="utf-8"
    )
)


@pytest.mark.parametrize(
    "hidden",
    [
        "​",  # zero width space
        "‌",  # zero width non-joiner
        "‍",  # zero width joiner, between letters
        "⁠",  # word joiner
        "﻿",  # byte order mark
        "­",  # soft hyphen
        "‎",  # left-to-right mark
        "‏",  # right-to-left mark
        "؜",  # Arabic letter mark
        "‮",  # right-to-left override
        "‬",
        "⁦",  # isolates
        "⁩",
        "\x00",
        "\x07",
        "\x1b",
        "\x7f",
        "\x9b",
        "͏",  # grapheme joiner
        "ᅟ",  # Hangul fillers
        "ㅤ",
        "⠀",  # Braille blank
        "️",  # variation, on a letter
        "\U000e0041",  # tag character
        "\U000e0101",  # variation supplement
        "￾",
        "\ud800",  # half a surrogate pair: JSON lets it in, the database does not
    ],
)
def test_a_hidden_character_is_taken_out(hidden: str) -> None:
    assert clean_message_text(f"ci{hidden}ao") == "ciao"
    assert clean_message_text(hidden * 3) == ""


@pytest.mark.parametrize(
    "text",
    [
        "Perché così? È già tardi: «sì»",
        "Großer Käfig für 40 €",
        "Vous avez raison : d'accord !",
        "<b>Ciao</b> <script>alert(1)</script> &amp;",
        "a\nb\n\nc",
        "\U0001f468‍\U0001f469‍\U0001f467",  # family
        "\U0001f3f3️‍\U0001f308",  # rainbow flag
        "\U0001f9d1\U0001f3fd‍⚕️",  # health worker, skin tone
        "\U0001f1ee\U0001f1f9",  # Italy
        "\U0001f3f4\U000e0067\U000e0062\U000e0073\U000e0063\U000e0074\U000e007f",  # Scotland
        "1️⃣",  # keycap
        "❤️‍\U0001f525 ☀️ ‼️",
        "é",  # combining accent
    ],
)
def test_visible_text_stays_as_it_is(text: str) -> None:
    assert clean_message_text(text) == text


def test_line_ends_and_tabs_become_plain() -> None:
    assert clean_message_text(" a\r\nb\rc d e\x0bf\tg ") == "a\nb\nc\nd\ne\nf g"


def test_cleaning_twice_changes_nothing_more() -> None:
    odd = "a‍️\U0001f468‍​\U0001f469️️‍ \U0001f3f4\U000e0067x"
    once = clean_message_text(odd)
    assert clean_message_text(once) == once
    assert "\U0001f468‍\U0001f469" in once
    assert "\U000e0067" not in once


@pytest.mark.parametrize("text", CASES["caution"])
def test_a_contact_or_a_code_is_recognised(text: str) -> None:
    assert needs_caution(text)


@pytest.mark.parametrize("text", CASES["fine"])
def test_an_ordinary_message_is_not(text: str) -> None:
    assert not needs_caution(text)


@pytest.mark.parametrize(
    "text",
    [
        "333​123⁠4567",
        "mario​@​example.com",
        "３３３１２３４５６７",  # full width digits
        "".join(f"{digit}️⃣" for digit in "3331234567"),  # keycaps
        "il co­dice di veri​fica",
    ],
)
def test_hiding_it_does_not_help(text: str) -> None:
    assert needs_caution(text)


@pytest.mark.parametrize(
    "unit", ["a", "a-", "1 ", "a.", "@", "codice ", "codice a ", "12 ", "25/11 ", "10.30-", "a@"]
)
def test_a_long_message_is_read_quickly(unit: str) -> None:
    text = (unit * 1000)[:1000]
    started = time.perf_counter()
    needs_caution(text)
    assert time.perf_counter() - started < 0.1
