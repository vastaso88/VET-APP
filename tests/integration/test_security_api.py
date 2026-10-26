"""Security regression tests at the HTTP layer (audit 2026-10-26)."""

import asyncio

import pytest
from fastapi import Request
from fastapi.testclient import TestClient

from apps.api.main import app, handle_provider_error, handle_unexpected_error
from apps.api.rate_limit import RateLimitRule, SlidingWindowLimiter
from packages.infrastructure.speech.groq_speech_to_text_provider import safe_multipart_values
from packages.shared.config.settings import Settings
from packages.shared.errors.base import ProviderError


def _request() -> Request:
    return Request({"type": "http", "method": "GET", "path": "/", "headers": []})


def test_security_headers_on_every_response() -> None:
    client = TestClient(app)

    response = client.get("/health", headers={"Authorization": "Bearer x"})

    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["X-Frame-Options"] == "DENY"
    assert response.headers["Referrer-Policy"] == "no-referrer"
    assert response.headers["Cache-Control"] == "no-store"


def test_provider_error_body_never_reaches_the_client() -> None:
    secret = "status 429: org_123 tokens per day remaining 0, model gpt-oss-120b"

    response = asyncio.run(handle_provider_error(_request(), ProviderError(secret)))

    body = bytes(response.body).decode()
    assert response.status_code == 502
    assert "org_123" not in body and "gpt-oss" not in body
    assert "error_id" in body


def test_unexpected_error_is_a_generic_500() -> None:
    response = asyncio.run(handle_unexpected_error(_request(), RuntimeError("db password=x")))

    body = bytes(response.body).decode()
    assert response.status_code == 500
    assert "password" not in body
    assert "error_id" in body


def test_login_is_throttled_per_client() -> None:
    client = TestClient(app)
    payload = {"email": "someone@example.com", "password": "guess"}
    headers = {"X-Forwarded-For": "203.0.113.7"}

    statuses = [
        client.post("/auth/login", json=payload, headers=headers).status_code for _ in range(11)
    ]

    assert 429 in statuses
    assert statuses[-1] == 429
    # Another client is not affected by the first one's burst.
    other = client.post("/auth/login", json=payload, headers={"X-Forwarded-For": "203.0.113.8"})
    assert other.status_code != 429


def test_sliding_window_limiter_recovers_after_the_window() -> None:
    now = [0.0]
    limiter = SlidingWindowLimiter(
        rules=(RateLimitRule(prefix="/x", limit=2, window_seconds=10.0),), clock=lambda: now[0]
    )
    rule = limiter.rule_for("POST", "/x/y")
    assert rule is not None
    assert limiter.allow(rule, "k") and limiter.allow(rule, "k")
    assert not limiter.allow(rule, "k")
    now[0] = 11.0
    assert limiter.allow(rule, "k")
    assert limiter.rule_for("GET", "/x/y") is None


def test_speech_to_text_rejects_oversized_audio() -> None:
    client = TestClient(app)

    response = client.post(
        "/speech-to-text",
        files={"file": ("a.webm", b"0" * (4 * 1024 * 1024 + 1), "audio/webm")},
        headers={"X-Forwarded-For": "203.0.113.9"},
    )

    assert response.status_code == 400
    assert "too large" in response.json()["detail"]


def test_multipart_values_cannot_inject_form_fields() -> None:
    evil_name = 'x.webm"\r\nContent-Disposition: form-data; name="model"\r\n\r\nwhisper-large'
    filename, content_type = safe_multipart_values(evil_name, 'audio/webm"\r\nX: y')

    assert "\r" not in filename and '"' not in filename
    assert "\r" not in content_type and '"' not in content_type
    assert filename == "audio.bin"
    assert content_type == "application/octet-stream"
    assert safe_multipart_values("voice.m4a", "audio/mp4; codecs=opus") == (
        "audio.m4a",
        "audio/mp4",
    )


def test_production_refuses_the_demo_auth_backend() -> None:
    with pytest.raises(ValueError, match="AUTH_BACKEND=supabase"):
        Settings(_env_file=None, ENVIRONMENT="production")  # type: ignore[call-arg]
    with pytest.raises(ValueError, match="AUTH_BACKEND=supabase"):
        Settings(  # type: ignore[call-arg]
            _env_file=None,
            ENVIRONMENT="production",
            AUTH_BACKEND="supabase",
            PERSISTENCE_BACKEND="in_memory",
            SUPABASE_URL="https://example.supabase.co",
            SUPABASE_ANON_KEY="sb_publishable_x",
            SUPABASE_SERVICE_ROLE_KEY="secret",
        )


def test_request_schemas_bound_text_lengths() -> None:
    client = TestClient(app)

    too_long = client.post("/pets", json={"name": "x" * 81, "species": "dog"})
    assert too_long.status_code == 422

    weak = client.post("/auth/login", json={"email": "a@b.c", "password": "p" * 73})
    assert weak.status_code == 422
