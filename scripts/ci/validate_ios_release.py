"""Validate public iOS build configuration; never print credential values."""

import argparse
import json
import re
from pathlib import Path

from scripts.ci.prepare_firebase_build import validate_public_key, validate_url


def validate(path: Path, build_number: str, team_id: str) -> None:
    if not re.fullmatch(r"[A-Z0-9]{10}", team_id):
        raise ValueError("APPLE_TEAM_ID must be the 10-character Apple team identifier.")
    if not re.fullmatch(r"[1-9][0-9]{0,3}", build_number):
        raise ValueError("Use an integer build number from 1 to 9999 for CFBundleVersion.")
    data = json.loads(path.read_text(encoding="utf-8"))
    allowed = {
        "ENVIRONMENT", "APP_NAME", "API_BASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY",
        "LOG_LEVEL", "ENABLE_TELEMETRY", "WALK_MAP_STYLE",
    }
    if not isinstance(data, dict) or set(data) - allowed:
        raise ValueError("Unexpected define keys: use only public runtime configuration.")
    if data.get("ENVIRONMENT") not in {"staging", "production"}:
        raise ValueError("A signed archive needs staging or production configuration.")
    for key in ("API_BASE_URL", "SUPABASE_URL"):
        value = data.get(key)
        if not isinstance(value, str) or any(c in value for c in "<>{}"):
            raise ValueError(f"{key} is missing or still contains a placeholder.")
        validate_url(value, key)
    public_key = data.get("SUPABASE_ANON_KEY")
    if not isinstance(public_key, str):
        raise ValueError("SUPABASE_ANON_KEY is missing.")
    validate_public_key(public_key)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--defines", type=Path, required=True)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--team-id", required=True)
    args = parser.parse_args()
    try:
        validate(args.defines, args.build_number, args.team_id)
    except (ValueError, OSError):
        # JSON parse and filesystem errors may include supplied values/paths.
        parser.exit(1, "Invalid iOS release inputs; check configuration, team and build number.\n")
    print("iOS release inputs validated (values omitted).")


if __name__ == "__main__":
    main()
