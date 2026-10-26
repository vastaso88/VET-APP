import base64
import json
import tempfile
import unittest
from pathlib import Path

from scripts.ci.prepare_firebase_build import PRIVATE_FILES, cleanup, prepare


class FirebaseBuildConfigTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / "distribution"
        self.env = {
            "API_BASE_URL": "https://api.example.test",
            "SUPABASE_URL": "https://test-project.supabase.co",
            "SUPABASE_ANON_KEY": "sb_publishable_test",
            "FIREBASE_ANDROID_APP_ID": "1:123456789:android:abcdef123",
            "FIREBASE_TESTER_GROUPS": "internal-testers,multilang",
            "FIREBASE_SERVICE_ACCOUNT_JSON": json.dumps(
                {
                    "type": "service_account",
                    "project_id": "test-project",
                    "client_email": "test@example.test",
                    "private_key": "test-private-key",
                }
            ),
            "ANDROID_KEYSTORE_BASE64": base64.b64encode(b"test-keystore").decode(),
            "ANDROID_KEYSTORE_PASSWORD": "test-store-password",
            "ANDROID_KEY_ALIAS": "test-key",
            "ANDROID_KEY_PASSWORD": "test-key-password",
            "ANDROID_BUILD_NUMBER": "31",
            "GITHUB_SHA": "abcdef",
            "GITHUB_REF_NAME": "MULTILANG",
            "TEST_RELEASE_NOTES": 'Test IT/EN/ES; "quotes" and $shell text',
        }

    def test_prepare_writes_only_public_defines_and_release_identity(self) -> None:
        prepare(self.env, self.directory)
        defines = json.loads((self.directory / "dart-defines.json").read_text())
        self.assertEqual(set(defines), {"API_BASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY"})
        self.assertNotIn("private_key", json.dumps(defines))
        self.assertEqual((self.directory / "signing.jks").read_bytes(), b"test-keystore")
        notes = (self.directory / "release-notes.txt").read_text()
        for text in ("MULTILANG", "abcdef", "31", self.env["TEST_RELEASE_NOTES"]):
            self.assertIn(text, notes)

    def test_accepts_legacy_anon_but_rejects_privileged_keys(self) -> None:
        for role in ("anon", "service_role", "authenticated"):
            with self.subTest(role=role):
                payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode()
                self.env["SUPABASE_ANON_KEY"] = f"header.{payload.rstrip('=')}.signature"
                if role == "anon":
                    prepare(self.env, self.directory)
                else:
                    with self.assertRaisesRegex(ValueError, "never service_role/secret"):
                        prepare(self.env, self.directory)

    def test_rejects_malformed_and_secret_keys(self) -> None:
        for key in ("sb_secret_private", "sb_publishable_", "bad-key", "a.e30.c", "a.W10.c"):
            with self.subTest(key=key):
                self.env["SUPABASE_ANON_KEY"] = key
                with self.assertRaises(ValueError):
                    prepare(self.env, self.directory)
                self.assertFalse(self.directory.exists())

    def test_rejects_local_or_insecure_endpoints(self) -> None:
        for name in ("API_BASE_URL", "SUPABASE_URL"):
            original = self.env[name]
            for url in (
                "http://api.example.test",
                "https://localhost",
                "https://127.0.0.1",
                "https://10.0.0.1",
                "https://[::1]",
                "https://host.local",
                "https://user:password@api.example.test",
                "",
            ):
                with self.subTest(name=name, url=url):
                    self.env[name] = url
                    with self.assertRaises(ValueError):
                        prepare(self.env, self.directory)
            self.env[name] = original

    def test_rejects_invalid_configuration_without_writing_private_files(self) -> None:
        invalid = {
            "ANDROID_BUILD_NUMBER": ("0", "-1", "1.5", "2100000001", "abc"),
            "FIREBASE_ANDROID_APP_ID": ("com.vetapp.vetapp", "1:123:ios:abc"),
            "FIREBASE_TESTER_GROUPS": ("", "group;command", "group, other"),
            "FIREBASE_SERVICE_ACCOUNT_JSON": ("not-json", "[]", "{}"),
            "ANDROID_KEYSTORE_BASE64": ("not-base64", "===="),
            "ANDROID_KEYSTORE_PASSWORD": ("",),
        }
        for name, values in invalid.items():
            original = self.env[name]
            for value in values:
                with self.subTest(name=name, value=value):
                    self.env[name] = value
                    with self.assertRaises(ValueError):
                        prepare(self.env, self.directory)
                    self.assertFalse(self.directory.exists())
            self.env[name] = original

    def test_cleanup_is_idempotent_and_does_not_remove_unrelated_files(self) -> None:
        prepare(self.env, self.directory)
        unrelated = self.directory / "unrelated.txt"
        unrelated.write_text("preserve")
        cleanup(self.directory)
        cleanup(self.directory)
        self.assertTrue(unrelated.exists())
        self.assertTrue(all(not (self.directory / name).exists() for name in PRIVATE_FILES))


if __name__ == "__main__":
    unittest.main()
