"""Collaudo F44: the second data export within ten minutes was refused with "riprova tra poco"
and a Retry-After of the whole window, so nobody knew how long. The answer now carries the
wait that is really left, in the caller's language."""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from apps.api.rate_limit import RateLimitRule, SlidingWindowLimiter, build_middleware


class _Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def _client(clock: _Clock) -> TestClient:
    rule = RateLimitRule(
        prefix="/export", limit=1, window_seconds=600.0, methods=frozenset({"GET"})
    )
    app = FastAPI()
    app.middleware("http")(build_middleware(SlidingWindowLimiter((rule,), clock=clock)))

    @app.get("/export")
    def export() -> dict[str, bool]:
        return {"ok": True}

    return TestClient(app)


def test_the_wait_that_is_left_is_told_not_the_whole_window() -> None:
    clock = _Clock()
    client = _client(clock)
    assert client.get("/export").status_code == 200

    clock.now += 180  # three minutes later: seven are left
    refused = client.get("/export")

    assert refused.status_code == 429
    assert refused.headers["Retry-After"] == "420"
    assert refused.json() == {"detail": "Troppe richieste: riprova tra 7 minuti."}


@pytest.mark.parametrize(
    ("language", "expected"),
    [
        ("it", "Troppe richieste: riprova tra 10 minuti."),
        ("en", "Too many requests: try again in 10 minutes."),
        ("es", "Demasiadas solicitudes: inténtalo de nuevo dentro de 10 minutos."),
        ("de", "Zu viele Anfragen: Versuchen Sie es in 10 Minuten erneut."),
        ("fr", "Trop de demandes\u00a0: réessayez dans 10 minutes."),
    ],
)
def test_the_refusal_speaks_the_callers_language(language: str, expected: str) -> None:
    clock = _Clock()
    client = _client(clock)
    client.get("/export", headers={"Accept-Language": language})

    refused = client.get("/export", headers={"Accept-Language": language})

    assert refused.status_code == 429
    assert refused.json()["detail"] == expected
    assert refused.headers["Retry-After"] == "600"


def test_a_short_wait_is_never_shown_as_zero() -> None:
    clock = _Clock()
    client = _client(clock)
    client.get("/export")

    clock.now += 599.4
    refused = client.get("/export")

    assert refused.status_code == 429
    assert refused.headers["Retry-After"] == "1"
    assert "pochi minuti" in refused.json()["detail"]
