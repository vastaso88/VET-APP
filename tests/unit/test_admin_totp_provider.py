"""Contract tests for the real GoTrue MFA endpoints used by admin writes.

GoTrue lists factors on GET /auth/v1/user. POST /auth/v1/factors enrolls
new factors; GET /auth/v1/factors returns an error on hosted Supabase Auth.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
from types import SimpleNamespace
from typing import Any

import pytest
from fastapi import HTTPException

from apps.api.routes import admin_users

ADMIN_ID = "11111111-1111-4111-8111-111111111111"
FACTOR_ID = "22222222-2222-4222-8222-222222222222"
CODE = "392815"


def _token(admin_id: str = ADMIN_ID, aal: str = "aal2") -> str:
    claims = json.dumps({"sub": admin_id, "aal": aal}).encode()
    return "e30." + base64.urlsafe_b64encode(claims).decode().rstrip("=") + ".signature"


def _provider(
    monkeypatch: pytest.MonkeyPatch,
    *,
    factors: list[dict[str, str]] | None = None,
    user_id: str = ADMIN_ID,
    user_status: int = 200,
    verify_status: int = 200,
    aal: str = "aal2",
) -> list[tuple[str, str]]:
    calls: list[tuple[str, str]] = []
    if factors is None:
        factors = [{"id": FACTOR_ID, "status": "verified", "factor_type": "totp"}]

    class Response:
        def __init__(self, code: int, data: dict[str, Any]) -> None:
            self.status_code = code
            self._data = data

        def json(self) -> dict[str, Any]:
            return self._data

    class Client:
        def __init__(self, timeout: float) -> None:
            assert timeout == 8.0

        def __enter__(self) -> Client:
            return self

        def __exit__(self, *_args: object) -> None:
            return None

        def get(self, url: str, *, headers: dict[str, str]) -> Response:
            calls.append(("GET", url))
            assert headers["Authorization"] == "Bearer test-session"
            assert url.endswith("/auth/v1/user")
            return Response(user_status, {"id": user_id, "factors": factors})

        def post(
            self, url: str, *, headers: dict[str, str], json: dict[str, str],
        ) -> Response:
            calls.append(("POST", url))
            if url.endswith("/challenge"):
                return Response(200, {"id": "challenge-id"})
            assert url.endswith("/verify")
            assert json == {"challenge_id": "challenge-id", "code": CODE}
            return Response(verify_status, {"access_token": _token(aal=aal)})

    monkeypatch.setattr(admin_users.httpx, "Client", Client)
    monkeypatch.setattr(admin_users, "get_access_token", lambda: "test-session")
    monkeypatch.setattr(
        admin_users,
        "get_container",
        lambda: SimpleNamespace(settings=SimpleNamespace(
            supabase_url="https://example.supabase.co",
            supabase_anon_key="public-key",
            reporter_pseudonym_secret=lambda: "test-secret",
        )),
    )
    return calls


def test_admin_totp_reads_verified_factors_from_auth_user(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = _provider(monkeypatch)
    proof = admin_users._verify_plan_totp(ADMIN_ID, CODE)
    expected = hmac.new(
        b"test-secret", f"admin-plan-totp:{ADMIN_ID}:{CODE}".encode(), hashlib.sha256,
    ).hexdigest()
    assert proof == expected
    assert calls == [
        ("GET", "https://example.supabase.co/auth/v1/user"),
        ("POST", f"https://example.supabase.co/auth/v1/factors/{FACTOR_ID}/challenge"),
        ("POST", f"https://example.supabase.co/auth/v1/factors/{FACTOR_ID}/verify"),
    ]


def test_admin_totp_blocks_unverified_factor(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = _provider(
        monkeypatch,
        factors=[{"id": FACTOR_ID, "factor_type": "totp", "status": "unverified"}],
    )
    with pytest.raises(HTTPException) as exc:
        admin_users._verify_plan_totp(ADMIN_ID, CODE)
    assert exc.value.status_code == 428
    assert len(calls) == 1


def test_admin_totp_blocks_mismatched_user(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = _provider(monkeypatch, user_id="33333333-3333-4333-8333-333333333333")
    with pytest.raises(HTTPException) as exc:
        admin_users._verify_plan_totp(ADMIN_ID, CODE)
    assert exc.value.status_code == 403
    assert len(calls) == 1


@pytest.mark.parametrize(
    ("status", "expected_status"),
    [(401, 401), (403, 401), (404, 503)],
)
def test_admin_totp_handles_provider_status(
    monkeypatch: pytest.MonkeyPatch, status: int, expected_status: int,
) -> None:
    calls = _provider(monkeypatch, user_status=status)
    with pytest.raises(HTTPException) as exc:
        admin_users._verify_plan_totp(ADMIN_ID, CODE)
    assert exc.value.status_code == expected_status
    assert len(calls) == 1


def test_admin_totp_rejects_wrong_code(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _provider(monkeypatch, verify_status=400)
    with pytest.raises(HTTPException) as exc:
        admin_users._verify_plan_totp(ADMIN_ID, CODE)
    assert exc.value.status_code == 400


def test_admin_totp_requires_assurance_level_two(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _provider(monkeypatch, aal="aal1")
    with pytest.raises(HTTPException) as exc:
        admin_users._verify_plan_totp(ADMIN_ID, CODE)
    assert exc.value.status_code == 403
