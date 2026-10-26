"""Guards for the app translations (scripts/i18n/check_i18n.py).

The last two tests run the guard on the real repository: they fail when someone
writes an Italian string straight into the Dart code or adds a language file
that lacks keys of ``app_it.arb``.
"""

import importlib.util
import json
import sys
from pathlib import Path
from types import ModuleType

import pytest

ROOT_DIR = Path(__file__).resolve().parents[2]


def _load_script() -> ModuleType:
    path = ROOT_DIR / "scripts" / "i18n" / "check_i18n.py"
    spec = importlib.util.spec_from_file_location("check_i18n", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules["check_i18n"] = module
    spec.loader.exec_module(module)
    return module


check_i18n = _load_script()


@pytest.mark.parametrize(
    "text",
    ["Annulla", "Non è stato possibile salvare", "Il tuo cane", "Perché?", "Promemoria"],
)
def test_italian_text_is_detected(text: str) -> None:
    assert check_i18n.italian_score(text)


@pytest.mark.parametrize("text", ["https://example.com", "vet_app.unit_system", "id", "Cancel"])
def test_technical_text_is_not_flagged(text: str) -> None:
    assert not check_i18n.italian_score(text)


def test_placeholders_are_extracted_from_icu_messages() -> None:
    message = "{count, plural, =1{1 profilo} other{{count} profili}} di {name}"
    assert check_i18n.arb_placeholders(message) == {"count", "name"}


def test_plural_branch_words_are_not_placeholders() -> None:
    assert check_i18n.arb_placeholders("{days, plural, =1{day} other{days}}") == {"days"}


def test_missing_keys_and_placeholder_mismatches_are_reported(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    (tmp_path / "app_it.arb").write_text(
        json.dumps({"@@locale": "it", "hello": "Ciao {name}", "bye": "Arrivederci"}),
        encoding="utf-8",
    )
    (tmp_path / "app_en.arb").write_text(
        json.dumps({"@@locale": "en", "hello": "Hello", "extra": "x"}), encoding="utf-8"
    )
    monkeypatch.setattr(check_i18n, "L10N", tmp_path)
    monkeypatch.setattr(check_i18n, "TEMPLATE", tmp_path / "app_it.arb")

    missing, extra, mismatched = check_i18n.compare_arbs()

    assert missing == {"en": ["bye"], "es": ["hello", "bye"], "fr": ["hello", "bye"]}
    assert extra == {"en": ["extra"], "es": [], "fr": []}
    assert mismatched == {"en": ["hello"], "es": [], "fr": []}


def test_repository_has_no_hardcoded_italian_strings() -> None:
    found = check_i18n.find_hardcoded()
    assert found == [], "\n".join(f"{rel}:{n}: {text}" for rel, n, text in found[:40])


def test_every_language_file_has_all_template_keys() -> None:
    missing, extra, mismatched = check_i18n.compare_arbs()
    assert {lang: keys for lang, keys in missing.items() if keys} == {}
    assert {lang: keys for lang, keys in mismatched.items() if keys} == {}
    assert {lang: keys for lang, keys in extra.items() if keys} == {}


@pytest.mark.parametrize("text", ["save", "hello $name", "Guardar", "Account"])
def test_ui_literals_are_detected_independently_of_language(text: str) -> None:
    assert check_i18n.looks_like_ui_text(text)


def test_multiline_widget_literal_is_detected(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    library = tmp_path / "lib"
    library.mkdir()
    (library / "page.dart").write_text("Text(\n  'save changes',\n);", encoding="utf-8")
    monkeypatch.setattr(check_i18n, "LIB", library)
    monkeypatch.setattr(check_i18n, "APP", tmp_path)
    monkeypatch.setattr(check_i18n, "ALLOWLIST", tmp_path / "nonexistent")
    assert check_i18n.find_hardcoded() == [("lib/page.dart", 1, "save changes")]
