"""Prepare an Android Play test bundle; never upload it or embed private credentials."""

import argparse
import base64
import binascii
import json
import os
from pathlib import Path
from urllib.parse import urlsplit

from scripts.ci.prepare_firebase_build import validate_public_key, validate_url

PRIVATE_FILES = ("dart-defines.json", "signing.jks")
REQUIRED = (
    "API_BASE_URL",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
    "ANDROID_BUILD_NUMBER",
)


def prepare(env: dict[str, str], directory: Path) -> None:
    missing = [name for name in REQUIRED if not env.get(name, "").strip()]
    if missing:
        raise ValueError("Missing configuration: " + ", ".join(missing))
    for name in ("API_BASE_URL", "SUPABASE_URL"):
        validate_url(env[name], name)
        url = urlsplit(env[name])
        if url.path not in ("", "/") or url.query or url.fragment:
            raise ValueError(f"{name} must be an HTTPS origin without path/query/fragment.")
    validate_public_key(env["SUPABASE_ANON_KEY"])
    number = env["ANDROID_BUILD_NUMBER"]
    if not number.isascii() or not number.isdecimal() or not 1 <= int(number) <= 2100000000:
        raise ValueError("ANDROID_BUILD_NUMBER must be an integer from 1 to 2100000000.")
    if env["ANDROID_KEY_ALIAS"].strip().lower() == "androiddebugkey":
        raise ValueError("A Play bundle must not use the Android debug key.")
    try:
        keystore = base64.b64decode(env["ANDROID_KEYSTORE_BASE64"], validate=True)
        if not keystore:
            raise ValueError("Empty keystore")
    except (ValueError, binascii.Error):
        raise ValueError("ANDROID_KEYSTORE_BASE64 must encode a nonempty keystore.") from None
    defines = {name: env[name] for name in ("API_BASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY")}
    # A staging backend still needs production-mode auth, with demo access disabled.
    defines.update(ENVIRONMENT="production", BILLING_DEMO_ENABLED="false")
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    for name, content in {
        "dart-defines.json": json.dumps(defines).encode(),
        "signing.jks": keystore,
    }.items():
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
    directory = Path(os.environ["RUNNER_TEMP"]) / "quokka-play"
    if args.cleanup:
        cleanup(directory)
        return
    try:
        prepare(dict(os.environ), directory)
    except ValueError as error:
        raise SystemExit(str(error)) from None
    print("Play build inputs validated; private files prepared (no upload).")


if __name__ == "__main__":
    main()
