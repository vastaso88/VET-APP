import json
import tempfile
import unittest
from pathlib import Path

from scripts.ci.validate_ios_release import validate


class IosReleaseConfigTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "defines.json"
        self.data = {
            "ENVIRONMENT": "staging",
            "API_BASE_URL": "https://api.example.test",
            "SUPABASE_URL": "https://example.supabase.co",
            "SUPABASE_ANON_KEY": "sb_publishable_test",
        }

    def check(self, number: str = "42", team: str = "ABCDEFGHIJ") -> None:
        self.path.write_text(json.dumps(self.data), encoding="utf-8")
        validate(self.path, number, team)

    def test_accepts_staging_and_production(self) -> None:
        for environment in ("staging", "production"):
            self.data["ENVIRONMENT"] = environment
            self.check()

    def test_rejects_demo_configuration(self) -> None:
        self.data["ENVIRONMENT"] = "development"
        with self.assertRaises(ValueError):
            self.check()

    def test_rejects_private_keys_and_unknown_flags(self) -> None:
        self.data["SUPABASE_ANON_KEY"] = "sb_secret_do_not_embed"
        with self.assertRaises(ValueError):
            self.check()
        self.data["SUPABASE_ANON_KEY"] = "sb_publishable_test"
        self.data["BILLING_DEMO_ENABLED"] = "true"
        with self.assertRaises(ValueError):
            self.check()

    def test_rejects_placeholder_and_insecure_endpoints(self) -> None:
        for url in ("https://<backend>", "http://api.example.test", "https://127.0.0.1"):
            self.data["API_BASE_URL"] = url
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.check()

    def test_rejects_invalid_signing_and_version_inputs(self) -> None:
        for number, team in (
            ("0", "ABCDEFGHIJ"), ("10000", "ABCDEFGHIJ"),
            ("42", "TODO"), ("42;echo", "ABCDEFGHIJ"),
        ):
            with self.subTest(number=number, team=team), self.assertRaises(ValueError):
                self.check(number, team)
