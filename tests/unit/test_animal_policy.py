import json
import subprocess
import sys
from pathlib import Path

import pytest

from packages.core.domain.marketplace.animal_policy import (
    ANIMAL_POLICY_MESSAGE,
    PATTERN_SOURCES,
    normalize_text,
    offers_animals,
)

ROOT = Path(__file__).resolve().parents[2]
CASES = json.loads(
    (ROOT / "tests/fixtures/marketplace_animal_policy_cases.json").read_text(encoding="utf-8")
)
BLOCKED = [tuple(case) for case in CASES["blocked"]]
ALLOWED = [tuple(case) for case in CASES["allowed"]]


@pytest.mark.parametrize(("title", "description"), BLOCKED)
def test_an_offer_of_an_animal_is_blocked(title: str, description: str | None) -> None:
    assert offers_animals(title, description) is True


@pytest.mark.parametrize(("title", "description"), ALLOWED)
def test_an_accessory_is_never_mistaken_for_an_animal(title: str, description: str | None) -> None:
    assert offers_animals(title, description) is False


def test_the_corpus_is_big_enough_to_mean_something() -> None:
    assert len(BLOCKED) >= 60 and len(ALLOWED) >= 70


def test_every_language_is_covered_by_both_lists() -> None:
    blocked_text = " ".join(f"{t} {d or ''}" for t, d in BLOCKED).lower()
    for marker in ("vendo", "for sale", "en venta", "zu verkaufen", "à vendre"):
        assert marker in blocked_text, marker


@pytest.mark.parametrize(
    "text",
    [
        "Catalogo accessori",  # "cat" inside "catalogo"
        "Scatola trasporto",  # "gatto"/"cat" are not hidden in other words
        "Hundeleine verstellbar",  # a compound is one word
        "Caneva decorativa",  # "cane" is not a prefix match
        "Dogma",  # "dog" inside another word
        "Pugilato guanti",  # "pug" inside another word
    ],
)
def test_whole_words_only(text: str) -> None:
    assert offers_animals(text) is False


def test_accents_case_and_punctuation_do_not_matter() -> None:
    assert normalize_text("Chiots À VENDRE !!") == "chiots a vendre"
    assert offers_animals("CHIOTS À VENDRE") is True
    assert offers_animals("vendo   GATTO,,, persiano") is True
    assert offers_animals("Guinzaglio-per-CANE") is False


def test_empty_and_missing_texts_are_fine() -> None:
    assert offers_animals(None, None) is False
    assert offers_animals("", "") is False
    assert offers_animals("Pallina", None) is False


def test_the_title_and_the_description_cannot_hide_each_other() -> None:
    assert offers_animals("Cuccia per cani", "vendo anche cuccioli") is True
    assert offers_animals("Vendo", "cane") is False  # across two fields no pairing is invented


def test_the_message_is_the_one_the_owner_asked_for() -> None:
    assert (
        ANIMAL_POLICY_MESSAGE == "Sul Mercatino si vendono solo oggetti per animali, non animali."
    )


def test_generated_copies_for_the_app_and_the_database_are_up_to_date() -> None:
    result = subprocess.run(  # noqa: S603
        [sys.executable, str(ROOT / "scripts/maintenance/gen_animal_policy.py"), "--check"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_the_database_script_hides_without_deleting_and_previews_first() -> None:
    sql = (ROOT / "scripts/setup/marketplace_no_animals.sql").read_text(encoding="utf-8")
    assert "removed_policy" in sql
    assert "delete from" not in sql.lower()
    assert sql.index("PARTE A") < sql.index("PARTE B")
    assert "count(*) as annunci_da_nascondere" in sql
    # Postgres word boundaries, never Python's \b (which is a backspace there).
    assert r"\m" in sql and r"\M" in sql and r"\b" not in sql


def test_every_pattern_compiles_and_is_whole_word() -> None:
    for key, source in PATTERN_SOURCES.items():
        assert "<B>" in source or key == "young_of", key
        assert r"\b" not in source, key
