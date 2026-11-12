"""The header the app sends (`X-UTC-Offset-Minutes`) reaches the per-owner
counters through the real HTTP path: middleware, route, service, ledger."""

from __future__ import annotations

import re
from datetime import UTC, date, datetime
from pathlib import Path
from typing import cast

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.domain.llm_usage.models import owner_day
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository

OWNER = "demo-user"


@pytest.fixture(autouse=True)
def _no_test_plan(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUBSCRIPTION_TEST_PLAN", "")


def _counted_days() -> set[date]:
    ledger = cast(InMemoryLlmUsageRepository, get_container().llm_usage_repository)
    return {day for (owner, day) in ledger._user_usage if owner == OWNER}  # noqa: SLF001


def _pet_id(client: TestClient) -> str:
    return str(
        client.post("/pets", json={"name": "Nina", "species": "dog"}).json()["pet_profile"]["id"]
    )


def _ask(client: TestClient, pet_id: str, **headers: str) -> int:
    return client.post(
        "/chat", json={"pet_id": pet_id, "user_message": "Mangia poco"}, headers=headers
    ).status_code


def test_the_question_is_counted_under_the_day_of_the_phones_clock() -> None:
    client = TestClient(app)
    pet_id = _pet_id(client)
    now = datetime.now(UTC)

    assert _ask(client, pet_id, **{"X-UTC-Offset-Minutes": "840"}) == 200

    assert _counted_days() == {owner_day(now, 840)}


def test_without_the_header_the_day_is_the_utc_day() -> None:
    client = TestClient(app)
    pet_id = _pet_id(client)
    now = datetime.now(UTC)

    assert _ask(client, pet_id) == 200

    assert _counted_days() == {owner_day(now, 0)}


@pytest.mark.parametrize("sent", ["abc", "9999", "61", "1e2", ""])
def test_a_header_that_is_not_believable_is_treated_as_utc(sent: str) -> None:
    client = TestClient(app)
    pet_id = _pet_id(client)
    now = datetime.now(UTC)

    assert _ask(client, pet_id, **{"X-UTC-Offset-Minutes": sent}) == 200

    assert _counted_days() == {owner_day(now, 0)}


def test_the_offset_of_one_request_does_not_leak_into_the_next() -> None:
    client = TestClient(app)
    pet_id = _pet_id(client)
    now = datetime.now(UTC)

    _ask(client, pet_id, **{"X-UTC-Offset-Minutes": "-720"})
    _ask(client, pet_id)

    assert _counted_days() == {owner_day(now, -720), owner_day(now, 0)}


def test_production_cors_lets_the_browser_send_the_header() -> None:
    # Tests run on the open development CORS branch, so the production list is
    # checked where it is written: a browser would otherwise refuse the request.
    source = (Path(__file__).resolve().parents[2] / "apps" / "api" / "main.py").read_text(
        encoding="utf-8"
    )
    allowed = re.search(r"allow_headers=\[([^\]]*)\],\s*\)\s*else:", source, re.DOTALL)

    assert allowed is not None
    assert '"X-UTC-Offset-Minutes"' in allowed.group(1)
