"""GET /admin/llm-usage: the portal's AI usage page. Only an admin reaches it, it
returns aggregates from the usage ledger and nothing that names a person."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.ports.auth_provider import AuthenticatedUser
from packages.core.domain.llm_usage.models import LlmUsageEvent

ADMIN = "admin-1"
PATH = "/admin/llm-usage"


def _act_as(monkeypatch: pytest.MonkeyPatch, user_id: str, *, verified: bool = True) -> None:
    monkeypatch.setattr(
        get_container().auth_provider,
        "get_current_user",
        lambda: AuthenticatedUser(
            id=user_id, email=f"{user_id}@example.com", email_verified=verified
        ),
    )


@pytest.fixture
def portal(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setattr(
        "apps.api.routes.admin._configured_admin_emails",
        lambda: frozenset({f"{ADMIN}@example.com"}),
    )
    # The region the costs are counted in is a setting (US by default in
    # production): pinned here so the figures below do not depend on it.
    monkeypatch.setenv("ANTHROPIC_INFERENCE_GEO", "global")
    return TestClient(app)


def _record(model: str, *, prompt: int, completion: int, calls: int = 1) -> None:
    repository = get_container().llm_usage_repository
    for _ in range(calls):
        repository.record(
            LlmUsageEvent(
                model=model,
                purpose="answer",
                occurred_at=datetime.now(UTC),
                prompt_tokens=prompt,
                completion_tokens=completion,
                total_tokens=prompt + completion,
            )
        )


# --- who may read it ------------------------------------------------------------


def test_a_normal_user_gets_403(portal: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    _act_as(monkeypatch, "owner-b")

    response = portal.get(PATH)

    assert response.status_code == 403


def test_an_admin_with_an_unverified_address_gets_403(
    portal: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    _act_as(monkeypatch, ADMIN, verified=False)

    assert portal.get(PATH).status_code == 403


def test_without_any_admin_configured_the_route_is_closed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr("apps.api.routes.admin._configured_admin_emails", lambda: frozenset())
    _act_as(monkeypatch, ADMIN)

    assert TestClient(app).get(PATH).status_code == 503


def test_an_admin_gets_the_report(portal: TestClient, monkeypatch: pytest.MonkeyPatch) -> None:
    _act_as(monkeypatch, ADMIN)

    response = portal.get(PATH)

    assert response.status_code == 200
    body = response.json()
    assert set(body) >= {
        "today",
        "month",
        "models",
        "daily",
        "sonnet_answers_today",
        "reserve_calls_today",
        "usd_per_eur",
    }
    assert len(body["daily"]) == 30


# --- what it says ---------------------------------------------------------------------


def test_it_reports_what_the_ledger_holds(
    portal: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    _record("claude-haiku-5-5", prompt=1_000_000, completion=0)  # $0.10
    _record("claude-sonnet-5-5", prompt=0, completion=100_000, calls=2)  # 2 x $1.00
    _record("openai/gpt-oss-120b", prompt=500, completion=100, calls=3)
    _act_as(monkeypatch, ADMIN)

    body = portal.get(PATH).json()

    assert body["today"]["spent_usd"] == pytest.approx(2.10)
    assert body["today"]["cap_eur"] == 1.0
    assert body["today"]["state"] == "exhausted"  # 2.10 USD is over the 1 EUR cap
    assert body["month"]["spent_usd"] == pytest.approx(2.10)
    assert body["month"]["credits_usd"] == 100.0
    assert body["sonnet_answers_today"] == 2
    assert body["reserve_calls_today"] == 3
    labels = {model["label"]: model for model in body["models"]}
    assert set(labels) == {"Haiku 5.5", "Sonnet 5.5", "gpt-oss-120b"}
    assert labels["Sonnet 5.5"]["today"]["calls"] == 2
    assert body["daily"][-1]["usd"] == pytest.approx(2.10)


def test_the_month_credits_come_from_the_environment(
    portal: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("LLM_MONTHLY_CREDITS_USD", "250")
    _act_as(monkeypatch, ADMIN)

    assert portal.get(PATH).json()["month"]["credits_usd"] == 250.0


# --- what it never says ---------------------------------------------------------------------


def _all_keys(value: Any) -> set[str]:
    if isinstance(value, dict):
        return set(value) | {key for item in value.values() for key in _all_keys(item)}
    if isinstance(value, list):
        return {key for item in value for key in _all_keys(item)}
    return set()


def test_it_carries_no_owner_no_text_and_no_personal_data(
    portal: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    _record("claude-haiku-5-5", prompt=100, completion=50)
    _act_as(monkeypatch, ADMIN)

    response = portal.get(PATH)

    assert not (
        _all_keys(response.json())
        & {"owner_id", "user_id", "email", "text", "message", "content", "purpose", "pet_id"}
    )
    assert ADMIN not in response.text and "example.com" not in response.text


def test_a_ledger_failure_is_a_plain_503_without_its_details(
    portal: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    def broken(*_: object) -> list[object]:
        raise RuntimeError("password=hunter2 host=db.internal")

    monkeypatch.setattr(get_container().llm_usage_repository, "usage_for_days", broken)
    _act_as(monkeypatch, ADMIN)

    response = portal.get(PATH)

    assert response.status_code == 503
    assert "hunter2" not in response.text and "db.internal" not in response.text
