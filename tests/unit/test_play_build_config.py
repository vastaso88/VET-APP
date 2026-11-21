import base64
import json
import tempfile
import unittest
from pathlib import Path

from scripts.ci.prepare_play_build import cleanup, prepare


class PlayBuildConfigTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / "play"
        self.env = {
            "API_BASE_URL": "https://api.example.test",
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_ANON_KEY": "sb_publishable_test",
            "ANDROID_KEYSTORE_BASE64": base64.b64encode(b"test-keystore").decode(),
            "ANDROID_KEYSTORE_PASSWORD": "private-password",
            "ANDROID_KEY_ALIAS": "upload",
            "ANDROID_KEY_PASSWORD": "private-password",
            "ANDROID_BUILD_NUMBER": "42",
            "ENVIRONMENT": "development",
            "BILLING_DEMO_ENABLED": "true",
        }

    def test_only_public_config_is_embedded_and_demo_cannot_be_enabled(self) -> None:
        prepare(self.env, self.directory)
        defines = json.loads((self.directory / "dart-defines.json").read_text())
        self.assertEqual(defines["ENVIRONMENT"], "production")
        self.assertEqual(defines["BILLING_DEMO_ENABLED"], "false")
        self.assertEqual(len(defines), 5)
        self.assertNotIn("private-password", json.dumps(defines))
        self.assertEqual((self.directory / "signing.jks").read_bytes(), b"test-keystore")

    def test_invalid_inputs_fail_before_writing_private_files(self) -> None:
        invalid = {
            "ANDROID_KEY_ALIAS": ["androiddebugkey", " AndroidDebugKey "],
            "ANDROID_BUILD_NUMBER": ["0", "-1", "2100000001", "1.5", "１２"],
            "SUPABASE_ANON_KEY": ["sb_secret_private", "bad-key"],
            "API_BASE_URL": [
                "http://api.example.test",
                "https://127.0.0.1",
                "https://api.example.test/path",
                "https://api.example.test?secret=x",
            ],
            "ANDROID_KEYSTORE_BASE64": ["invalid!", "===="],
            "ANDROID_KEYSTORE_PASSWORD": [""],
        }
        for name, values in invalid.items():
            for value in values:
                with self.subTest(name=name, value=value):
                    with self.assertRaises(ValueError):
                        prepare({**self.env, name: value}, self.directory)
                    self.assertFalse(self.directory.exists())

    def test_cleanup_preserves_unrelated_files(self) -> None:
        prepare(self.env, self.directory)
        (self.directory / "keep.txt").write_text("keep")
        cleanup(self.directory)
        cleanup(self.directory)
        self.assertEqual([p.name for p in self.directory.iterdir()], ["keep.txt"])
