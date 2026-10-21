import base64
import json
from datetime import UTC, datetime

from packages.infrastructure.auth.supabase_auth_provider import sign_in_time_from_token


def _token(payload: dict[str, object]) -> str:
    def part(data: dict[str, object]) -> str:
        raw = json.dumps(data).encode()
        return base64.urlsafe_b64encode(raw).decode().rstrip("=")

    return f"{part({'alg': 'HS256'})}.{part(payload)}.signature"


def test_the_newest_authentication_method_timestamp_is_the_sign_in() -> None:
    token = _token(
        {
            "iat": 2_000_000_000,  # refreshed long after the login
            "amr": [
                {"method": "otp", "timestamp": 1_000_000_000},
                {"method": "password", "timestamp": 1_000_000_500},
            ],
        }
    )
    assert sign_in_time_from_token(token) == datetime.fromtimestamp(1_000_000_500, UTC)


def test_without_amr_the_issue_time_is_used() -> None:
    assert sign_in_time_from_token(_token({"iat": 1_700_000_000})) == datetime.fromtimestamp(
        1_700_000_000, UTC
    )


def test_garbage_gives_none() -> None:
    assert sign_in_time_from_token("not-a-jwt") is None
    assert sign_in_time_from_token(_token({"sub": "x"})) is None
    assert sign_in_time_from_token("a.%%%.c") is None
