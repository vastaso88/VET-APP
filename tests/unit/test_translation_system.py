"""The pieces that keep future translations consistent: glossary, draft review list, register,
and the languages every backend catalog must cover (docs/i18n/NUOVE_FUNZIONI.md)."""

import io
import json
import tempfile
from pathlib import Path
from unittest.mock import patch

from scripts.i18n import glossary
from scripts.i18n.auto_translate import ROOT, Catalogs, digest, main, protected_xml


def test_feature_names_match_the_glossary_in_every_catalog() -> None:
    assert glossary.strict_problems(ROOT) == []


def test_glossary_covers_every_language_with_no_empty_term() -> None:
    for term in glossary.load(ROOT):
        for lang in ("it", *glossary.LANGUAGES):
            assert term[lang].strip(), (term["id"], lang)


def test_glossary_table_in_the_docs_is_up_to_date() -> None:
    assert glossary.render_into_doc(ROOT, check=True), "run: python scripts/i18n/glossary.py render"


def test_soft_hint_names_the_missing_term_and_accepts_aliases_and_plurals() -> None:
    terms = glossary.load(ROOT)
    wrong = glossary.soft_issues("Apri la cartella clinica", "de", "Öffne die Patientenakte", terms)
    assert wrong and "Krankenakte" in wrong[0]
    assert not glossary.soft_issues(
        "Apri la cartella clinica", "de", "Öffne die Krankenakte", terms
    )
    assert not glossary.soft_issues("Chiedi al veterinario", "en", "Ask your vet", terms)
    assert not glossary.soft_issues("Due referti", "fr", "Deux comptes rendus", terms)


def test_draft_is_marked_for_review_and_lists_glossary_misses() -> None:
    catalogs = Catalogs(ROOT)
    name = "ui:remindersTitle"
    catalogs.sources[name] = digest("Changed source")
    catalogs.entries[name]["it"] = "Apri il Monitoraggio"
    with (
        tempfile.TemporaryDirectory() as temporary,
        patch("scripts.i18n.auto_translate.Catalogs", return_value=catalogs),
        patch("scripts.i18n.auto_translate.deepl", return_value="Open the dashboard"),
        patch("sys.argv", ["auto_translate", "draft", "--output", temporary]),
    ):
        assert main() == 0
        folder = Path(temporary)
        rows = json.loads((folder / "TRANSLATION_REVIEW.json").read_text(encoding="utf-8"))
        markdown = (folder / "TRANSLATION_REVIEW.md").read_text(encoding="utf-8")
    assert {row["status"] for row in rows} == {"machine-draft"}
    assert {row["language"] for row in rows} == {"en", "es", "de", "fr"}
    assert "DA RIVEDERE" in markdown
    assert any("Monitoring" in issue for row in rows for issue in row["glossary"])


def test_deepl_asks_for_the_register_the_style_guide_decided() -> None:
    xml, _ = protected_xml("Ciao")
    expected = {"en": None, "es": "prefer_less", "de": "prefer_more", "fr": "prefer_more"}
    for language, formality in expected.items():
        response = io.BytesIO(json.dumps({"translations": [{"text": xml}]}).encode())
        with (
            patch.dict("os.environ", {"DEEPL_API_KEY": "test:fx"}, clear=True),
            patch("scripts.i18n.auto_translate.urlopen", return_value=response) as network,
        ):
            from scripts.i18n.auto_translate import deepl

            deepl("Ciao", language)
        payload = json.loads(network.call_args.args[0].data)
        assert payload.get("formality") == formality, language


def test_every_backend_catalog_covers_every_supported_language() -> None:
    """A language added to SUPPORTED_LANGUAGES must reach every fixed-text catalog. The one
    open gap is listed on purpose: fix it, then delete the entry."""
    from packages.core.application.services import interview_planner, response_generator
    from packages.core.application.services.chat_orchestrator import ChatOrchestrator
    from packages.core.domain.common.language import SUPPORTED_LANGUAGES
    from packages.core.domain.consent.account_consent_text import CONSENT_TEXTS_BY_LANGUAGE
    from packages.core.domain.localization import _MESSAGES, SUPPORTED_LOCALES
    from packages.core.domain.safety import triage_clarification

    known_gaps = {("account consent texts", "de"), ("account consent texts", "fr")}
    languages = set(SUPPORTED_LANGUAGES)
    assert languages == set(SUPPORTED_LOCALES)
    catalogs: dict[str, set[str]] = {
        "fixed messages": set.intersection(
            *({str(code) for code in values} for values in _MESSAGES.values())
        ),
        "connectors": set(response_generator._CONNECTORS),
        "interview questions": set(interview_planner.InterviewPlanner.QUESTION_TEMPLATES_BY_LOCALE),
        "small talk": set(ChatOrchestrator._SMALL_TALK_TEXTS),
        "account consent texts": set(CONSENT_TEXTS_BY_LANGUAGE),
    }
    for language in languages:
        catalogs.setdefault("triage questions", set())
        if triage_clarification.clarifying_question("respiratory", language) is not None:
            catalogs["triage questions"].add(language)
    missing = {
        (name, language) for name, covered in catalogs.items() for language in languages - covered
    }
    assert missing == known_gaps & missing, (
        f"languages with no text: {sorted(missing - known_gaps)}"
    )
    stale = known_gaps - missing
    assert not stale, f"gap closed, remove it from known_gaps: {sorted(stale)}"


def test_small_talk_uses_the_register_of_the_style_guide() -> None:
    """German in "Sie", French in "vous", Spanish in "tú" (docs/i18n/GLOSSARIO_E_STILE.md)."""
    from packages.core.application.services.chat_orchestrator import ChatOrchestrator

    texts = ChatOrchestrator._SMALL_TALK_TEXTS
    german = " ".join(texts["de"].values())
    french = " ".join(texts["fr"].values())
    assert " du " not in f" {german.lower()} " and "erzähl mir" not in german.lower()
    assert " tu " not in f" {french.lower()} " and "raconte-moi" not in french.lower()
