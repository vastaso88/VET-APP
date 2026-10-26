import ast
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.i18n.auto_translate import (
    ARB,
    BACKEND,
    LANGUAGES,
    NATIVE,
    ROOT,
    Catalogs,
    deepl,
    digest,
    main,
    pending,
    protected_xml,
    restore_xml,
)


class AutoTranslateTest(unittest.TestCase):
    def test_draft_preserves_manually_edited_translation(self) -> None:
        catalogs = Catalogs(ROOT)
        name = "ui:authLoginTitle"
        catalogs.sources[name] = digest("Changed source")
        catalogs.entries[name]["en"] = "Manually revised title"
        with (
            tempfile.TemporaryDirectory() as temporary,
            patch("scripts.i18n.auto_translate.Catalogs", return_value=catalogs),
            patch(
                "scripts.i18n.auto_translate.deepl", return_value="Translated title"
            ) as translator,
        ):
            with patch("sys.argv", ["auto_translate", "draft", "--output", temporary]):
                self.assertEqual(main(), 0)
            self.assertEqual(catalogs.entries[name]["en"], "Manually revised title")
            self.assertEqual(catalogs.entries[name]["es"], "Translated title")
            self.assertEqual(translator.call_count, len(LANGUAGES) - 1)
            self.assertIn("MANUAL REVIEW", (Path(temporary) / "TRANSLATION_REVIEW.txt").read_text())

    def test_cost_limit_prevents_any_network_calls(self) -> None:
        catalogs = Catalogs(ROOT)
        catalogs.sources[next(iter(catalogs.entries))] = digest("Changed source")
        with (
            tempfile.TemporaryDirectory() as temporary,
            patch("scripts.i18n.auto_translate.Catalogs", return_value=catalogs),
            patch("scripts.i18n.auto_translate.deepl") as translator,
        ):
            with (
                patch(
                    "sys.argv",
                    ["auto_translate", "draft", "--output", temporary, "--max-messages", "1"],
                ),
                self.assertRaisesRegex(ValueError, "cost limit"),
            ):
                main()
            translator.assert_not_called()

    def test_deepl_request_masks_tokens_and_uses_free_endpoint(self) -> None:
        xml, _ = protected_xml("Ciao {name}")
        response = io.BytesIO(
            json.dumps({"translations": [{"text": xml.replace("Ciao", "Hello")}]}).encode()
        )
        with (
            patch.dict("os.environ", {"DEEPL_API_KEY": "test:fx"}, clear=True),
            patch("scripts.i18n.auto_translate.urlopen", return_value=response) as network,
        ):
            self.assertEqual(deepl("Ciao {name}", "en"), "Hello {name}")
            request = network.call_args.args[0]
            self.assertEqual(request.full_url, "https://api-free.deepl.com/v2/translate")
            payload = json.loads(request.data)
            self.assertEqual(payload["ignore_tags"], ["x"])
            self.assertEqual(payload["target_lang"], "EN-GB")

    def test_saved_draft_updates_each_domain_without_changing_source(self) -> None:
        catalogs = Catalogs(ROOT)
        before = catalogs.sources.copy()
        for name in (
            "ui:authLoginTitle",
            "backend:summary_subject",
            "android:dog_walks_widget_title",
        ):
            catalogs.entries[name]["en"] = "Test translation"
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary)
            catalogs.save(destination)
            ui = json.loads((destination / ARB / "app_en.arb").read_text(encoding="utf-8"))
            self.assertEqual(ui["authLoginTitle"], "Test translation")
            tree = ast.parse((destination / BACKEND).read_text(encoding="utf-8"))
            message_node = next(
                node.value
                for node in tree.body
                if isinstance(node, ast.AnnAssign)
                and isinstance(node.target, ast.Name)
                and node.target.id == "_MESSAGES"
            )
            self.assertIsNotNone(message_node)
            assert message_node is not None
            self.assertEqual(
                ast.literal_eval(message_node)["summary_subject"]["en"], "Test translation"
            )
            self.assertIn(
                "Test translation", (destination / NATIVE / "values-en/strings.xml").read_text()
            )
            self.assertFalse((destination / ARB / "app_it.arb").exists())
        self.assertEqual(catalogs.sources, before)

    def test_roundtrip_preserves_icu_placeholders_and_android_formats(self) -> None:
        messages = [
            "Ciao {name}",
            "{count, plural, =1{Un documento} other{{count} documenti}}",
            "{gender, select, male{Il suo {name}} other{Il loro {name}}}",
            "{n, plural, offset:1 =0{Nessuno} other{# animali}}",
            "In corso · %1$s · %%s|Altro nell\\'app",
            "Titolo\nTesto & <segno>",
        ]
        for message in messages:
            with self.subTest(message=message):
                xml, tokens = protected_xml(message)
                self.assertEqual(restore_xml(xml, tokens), message)

    def test_plural_branch_words_are_translatable_not_frozen(self) -> None:
        xml, tokens = protected_xml("{n, plural, =1{Un animale} other{{n} animali}}")
        translated = xml.replace("Un animale", "One pet").replace(" animali", " pets")
        self.assertEqual(
            restore_xml(translated, tokens), "{n, plural, =1{One pet} other{{n} pets}}"
        )

    def test_corrupted_tokens_are_rejected(self) -> None:
        xml, tokens = protected_xml("Ciao {name}")
        for invalid in (
            xml.replace("{name}", "{nombre}"),
            xml.replace('id="0"', 'id="1"'),
            "<text>Hello</text>",
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                restore_xml(invalid, tokens)

    def test_missing_api_key_fails_without_network_request(self) -> None:
        with (
            patch.dict("os.environ", {}, clear=True),
            patch("scripts.i18n.auto_translate.urlopen") as request,
        ):
            with self.assertRaisesRegex(ValueError, "DEEPL_API_KEY"):
                deepl("Ciao", "en")
            request.assert_not_called()

    def test_baseline_is_complete_and_source_edit_becomes_stale(self) -> None:
        catalogs = Catalogs(ROOT)
        manifest = catalogs.snapshot()
        self.assertFalse(pending(catalogs, manifest))
        name = next(iter(catalogs.entries))
        catalogs.sources[name] = digest("Changed Italian text")
        self.assertEqual(pending(catalogs, manifest), [(name, lang) for lang in LANGUAGES])

    def test_missing_translation_detected_even_without_source_changes(self) -> None:
        catalogs = Catalogs(ROOT)
        manifest = catalogs.snapshot()
        name = next(iter(catalogs.entries))
        catalogs.entries[name]["es"] = ""
        self.assertEqual(pending(catalogs, manifest), [(name, "es")])

    def test_repository_placeholders_roundtrip_and_all_domains_included(self) -> None:
        catalogs = Catalogs(ROOT)
        self.assertEqual(
            {name.split(":")[0] for name in catalogs.entries}, {"ui", "backend", "android"}
        )
        for name, values in catalogs.entries.items():
            with self.subTest(name=name):
                xml, tokens = protected_xml(values["it"])
                self.assertEqual(restore_xml(xml, tokens), values["it"])


if __name__ == "__main__":
    unittest.main()
