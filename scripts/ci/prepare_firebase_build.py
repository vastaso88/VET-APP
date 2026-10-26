"""Validate tester build inputs without printing credentials; stdlib only."""

import argparse
import base64
import binascii
import ipaddress
import json
import os
import re
from pathlib import Path
from urllib.parse import urlsplit

PRIVATE_FILES = (
    "dart-defines.json",
    "firebase-service-account.json",
    "signing.jks",
    "release-notes.txt",
)
REQUIRED = (
    "API_BASE_URL",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "FIREBASE_ANDROID_APP_ID",
    "FIREBASE_TESTER_GROUPS",
    "FIREBASE_SERVICE_ACCOUNT_JSON",
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
    "ANDROID_BUILD_NUMBER",
)


def validate_url(value: str, name: str) -> None:
    url = urlsplit(value)
    if url.scheme != "https" or not url.hostname or url.username or url.password:
        raise ValueError(f"{name} must be a public HTTPS URL without embedded credentials.")
    host = url.hostname.lower()
    if host == "localhost" or host.endswith((".localhost", ".local")):
        raise ValueError(f"{name} cannot point to a local machine.")
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return
    if not address.is_global:
        raise ValueError(f"{name} cannot use a private or loopback address.")


def validate_public_key(key: str) -> None:
    if key.startswith("sb_publishable_") and len(key) > len("sb_publishable_"):
        return
    try:
        segments = key.split(".")
        if len(segments) != 3:
            raise ValueError("Invalid key format")
        payload = json.loads(base64.urlsafe_b64decode(segments[1] + "=" * (-len(segments[1]) % 4)))
        if isinstance(payload, dict) and payload.get("role") == "anon":
            return
    except (ValueError, UnicodeError, binascii.Error):
        pass
    raise ValueError(
        "SUPABASE_ANON_KEY must be publishable or legacy anon, never service_role/secret."
    )


def prepare(env: dict[str, str], directory: Path) -> None:
    missing = [name for name in REQUIRED if not env.get(name, "").strip()]
    if missing:
        raise ValueError("Missing configuration: " + ", ".join(missing))
    for name in ("API_BASE_URL", "SUPABASE_URL"):
        validate_url(env[name], name)
    validate_public_key(env["SUPABASE_ANON_KEY"])
    if not re.fullmatch(r"1:\d+:android:[a-zA-Z0-9]+", env["FIREBASE_ANDROID_APP_ID"]):
        raise ValueError(
            "FIREBASE_ANDROID_APP_ID must be the Firebase Android App ID, not package name."
        )
    if not re.fullmatch(r"[\w-]+(?:,[\w-]+)*", env["FIREBASE_TESTER_GROUPS"], flags=re.ASCII):
        raise ValueError("FIREBASE_TESTER_GROUPS must contain comma-separated group aliases.")
    number = env["ANDROID_BUILD_NUMBER"]
    if not number.isascii() or not number.isdecimal() or not 1 <= int(number) <= 2100000000:
        raise ValueError("ANDROID_BUILD_NUMBER must be an integer from 1 to 2100000000.")
    try:
        account = json.loads(env["FIREBASE_SERVICE_ACCOUNT_JSON"])
        valid_account = isinstance(account, dict) and account.get("type") == "service_account"
        valid_account = valid_account and all(
            isinstance(account.get(field), str) and account[field].strip()
            for field in ("project_id", "client_email", "private_key")
        )
        if not valid_account:
            raise ValueError("Invalid service account")
    except (ValueError, TypeError):
        raise ValueError(
            "FIREBASE_SERVICE_ACCOUNT_JSON must be a service account JSON key."
        ) from None
    try:
        keystore = base64.b64decode(env["ANDROID_KEYSTORE_BASE64"], validate=True)
        if not keystore:
            raise ValueError("Empty keystore")
    except (ValueError, binascii.Error):
        raise ValueError("ANDROID_KEYSTORE_BASE64 must encode a nonempty keystore.") from None

    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    defines = {name: env[name] for name in ("API_BASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY")}
    # The app refuses to start in demo mode when this is set and the
    # Supabase defines are missing (bootstrap.dart), instead of silently
    # running with the fake sign-in.
    defines["ENVIRONMENT"] = "production"
    notes = (
        f"Branch: {env.get('GITHUB_REF_NAME', 'MULTILANG')}\n"
        f"Commit: {env.get('GITHUB_SHA', 'local')}\n"
        f"Android version code: {number}\n"
        f"{env.get('TEST_RELEASE_NOTES', '')}\n"
    )
    files = {
        "dart-defines.json": json.dumps(defines).encode(),
        "firebase-service-account.json": json.dumps(account).encode(),
        "signing.jks": keystore,
        "release-notes.txt": notes.encode(),
    }
    for name, content in files.items():
        path = directory / name
        path.write_bytes(content)
        path.chmod(0o600)


def cleanup(directory: Path) -> None:
    for name in PRIVATE_FILES:
        (directory / name).unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cleanup", action="store_true")
    args = parser.parse_args()
    directory = Path(os.environ["RUNNER_TEMP"]) / "vetapp-distribution"
    if args.cleanup:
        cleanup(directory)
        return
    try:
        prepare(dict(os.environ), directory)
    except ValueError as error:
        raise SystemExit(str(error)) from None
    print("Tester build configuration validated; private files prepared.")


if __name__ == "__main__":
    main()
