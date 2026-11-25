"""Collaudo K13: errors used to consume the owner's daily allowances (2 answers + 1 error 500 =
3 questions used; 3 uploads that ended in 500 = 3 photo readings out of 10). The rule: only
what the owner received is counted. The allowance is reserved first and given back when the
request fails through no fault of the owner (500, provider down, timeout, the client leaving),
once, and the model spend (`llm_usage`) is never touched.

Real app and middleware, bootstrap sign-in, in-memory ledger; the provider is simulated."""

from __future__ import annotations

import asyncio
import threading
from collections.abc import Iterator
from datetime import UTC, datetime
from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app
from packages.bootstrap.container import get_container
from packages.core.application.services.llm_budget import (
    LlmBudget,
    is_our_failure,
    refund_if_our_failure,
)
from packages.core.application.services.send_chat_message import SendChatMessageInput
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.persistence.in_memory_repositories import InMemoryLlmUsageRepository
from packages.shared.auth_context import access_token_context
from packages.shared.errors.base import (
    AuthenticationError,
    ProviderError,
    QuotaExceededError,
    ValidationError,
)

OWNER = "demo-user"
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


def _budget(repository: InMemoryLlmUsageRepository) -> LlmBudget:
    return LlmBudget(repository, budgets={"m": 1_000_000}, default_budget=1_000_000)


def _used(kind: str) -> int:
    repository = get_container().llm_usage_repository
    assert isinstance(repository, InMemoryLlmUsageRepository)
    return sum(
        counters.get(kind, 0)
        for (owner, _day), counters in repository._user_usage.items()
        if owner == OWNER
    )


@pytest.fixture
def client() -> Iterator[TestClient]:
    """500s come back as responses, as they do in production."""
    yield TestClient(app, raise_server_exceptions=False)


@pytest.fixture(autouse=True)
def allowances(monkeypatch: pytest.MonkeyPatch) -> None:
    container = get_container()
    monkeypatch.setattr(
        container,
        "settings",
        container.settings.model_copy(
            update={
                "chat_daily_vision_limit_per_user": 10,
                "chat_daily_summary_limit_per_user": 10,
            }
        ),
    )


def _pet(client: TestClient) -> str:
    created = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()
    return str(created["pet_profile"]["id"])


def _ask(client: TestClient, pet_id: str, text: str = "Mangia poco") -> Any:
    return client.post("/chat", json={"pet_id": pet_id, "user_message": text})


# --- questions ---------------------------------------------------------------------


def test_two_answers_and_one_server_error_use_two_questions_not_three(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    pet_id = _pet(client)
    assert _ask(client, pet_id, "Mangia poco").status_code == 200
    assert _ask(client, pet_id, "Beve molto").status_code == 200
    assert _used("messages") == 2

    budget = get_container().llm_budget

    def counted_then_broken(*_: object, **__: object) -> None:
        # The orchestrator counts the question before it answers; then something breaks.
        budget.admit(owner_id=OWNER, models=["demo-model"], user_daily_limit=10)
        raise RuntimeError("database exploded")

    monkeypatch.setattr(get_container().chat_orchestrator, "answer", counted_then_broken)

    response = _ask(client, pet_id, "Una terza domanda")

    assert response.status_code == 500
    assert _used("messages") == 2  # the error did not take a question


def test_an_apology_instead_of_an_answer_does_not_use_a_question(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    pet_id = _pet(client)
    assert _ask(client, pet_id).status_code == 200
    assert _used("messages") == 1

    def provider_down(self: object, request: object) -> object:
        raise ProviderError("Anthropic request failed with status 503")

    monkeypatch.setattr(EchoLLMClient, "generate", provider_down)

    response = _ask(client, pet_id, "Perde il pelo da una settimana")

    assert response.status_code == 200  # the chat answers with an apology, not an error
    assert _used("messages") == 1


def test_a_question_refused_for_the_limit_is_not_counted_past_the_limit() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository)
    now = datetime.now(UTC)

    with access_token_context("t"):
        for _ in range(2):
            assert budget.admit(owner_id="o", models=["m"], user_daily_limit=2) is None
        refused = budget.admit(owner_id="o", models=["m"], user_daily_limit=2)
        again = budget.admit(owner_id="o", models=["m"], user_daily_limit=2)

    assert refused is not None and again is not None and refused.reason == "user_limit"
    counted = repository.add_user_message("o", now.date()) - 1
    assert counted == 2


# --- the budget itself ---------------------------------------------------------------


def test_everything_counted_in_a_request_is_given_back_once_and_the_spend_is_kept() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository)
    day = datetime.now(UTC).date()

    with access_token_context("token"):
        budget.admit(owner_id="o", models=["m"], user_daily_limit=5)
        budget.admit_feature(owner_id="o", kind="vision", limit=5)
        budget.admit_feature(owner_id="o", kind="summary", limit=5)
        budget.admit_sonnet(owner_id="o", limit=3)
        budget.note_usage("m", 1200, prompt_tokens=1000, completion_tokens=200)
        spent_before = budget.used_today("m")

        assert budget.refund_request_quota_uses() == 4
        assert budget.refund_request_quota_uses() == 0  # never twice

    assert repository.add_user_message("o", day) == 1
    assert repository.add_user_usage("o", day, "vision") == 1
    assert repository.add_user_usage("o", day, "summary") == 1
    assert repository.add_user_usage("o", day, "sonnet") == 1
    assert budget.used_today("m") == spent_before == 1200  # money spent stays counted


def test_outside_a_request_nothing_is_remembered_and_nothing_is_given_back() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository)

    budget.admit_feature(owner_id="o", kind="vision", limit=5)

    assert budget.refund_request_quota_uses() == 0
    assert repository.add_user_usage("o", datetime.now(UTC).date(), "vision") == 2


def test_two_requests_never_give_back_each_others_uses() -> None:
    repository = InMemoryLlmUsageRepository()
    budget = _budget(repository)
    day = datetime.now(UTC).date()

    with access_token_context("first"):
        budget.admit_feature(owner_id="a", kind="vision", limit=5)
        with access_token_context("second"):
            budget.admit_feature(owner_id="b", kind="vision", limit=5)
            assert budget.refund_request_quota_uses() == 1
        assert budget.refund_request_quota_uses() == 1

    assert repository.add_user_usage("a", day, "vision") == 1
    assert repository.add_user_usage("b", day, "vision") == 1


def test_a_ledger_that_cannot_give_back_never_breaks_the_request(
    caplog: pytest.LogCaptureFixture,
) -> None:
    class NoRefund(InMemoryLlmUsageRepository):
        def remove_user_usage(self, owner_id: str, day: Any, kind: str) -> int:
            raise RuntimeError("function chat_user_daily_usage_remove_kind does not exist")

    budget = _budget(NoRefund())

    with access_token_context("t"):
        budget.admit_feature(owner_id="secret-owner", kind="vision", limit=5)
        assert budget.refund_request_quota_uses() == 1

    logged = " ".join(record.getMessage() for record in caplog.records)
    assert "secret-owner" not in logged


# --- photo reading -----------------------------------------------------------------------


def test_three_uploads_that_end_in_500_use_no_photo_reading(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    pet_id = _pet(client)

    def storage_down(*_: object, **__: object) -> None:
        raise RuntimeError("storage returned 415")

    monkeypatch.setattr(get_container().media_storage, "save", storage_down)

    for _ in range(3):
        response = client.post(
            "/chat-attachments",
            data={"pet_id": pet_id},
            files={"file": ("zampa.png", PNG_BYTES, "application/octet-stream")},
        )
        assert response.status_code == 500

    assert _used("vision") == 0


def test_a_photo_reading_that_fails_on_the_providers_side_is_given_back(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    pet_id = _pet(client)

    class Down:
        def analyze(self, *args: object, **kwargs: object) -> str:
            raise ProviderError("the photo service timed out")

    monkeypatch.setattr(get_container(), "image_analyzer", Down())
    _upload(client, pet_id)  # the file is saved, only the reading degrades

    assert _used("vision") == 0


def test_a_file_the_provider_refuses_as_invalid_stays_counted(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    pet_id = _pet(client)

    class Refuses:
        def analyze(self, *args: object, **kwargs: object) -> str:
            raise ProviderError("the photo service failed with status 400: invalid image")

    monkeypatch.setattr(get_container(), "image_analyzer", Refuses())
    _upload(client, pet_id)

    assert _used("vision") == 1  # no free round with the provider for invalid files


def test_an_invalid_file_is_refused_before_anything_is_counted(client: TestClient) -> None:
    pet_id = _pet(client)

    response = client.post(
        "/chat-attachments",
        data={"pet_id": pet_id},
        files={"file": ("nota.txt", b"just some text", "image/png")},
    )

    assert response.status_code == 400
    assert _used("vision") == 0


def _upload(client: TestClient, pet_id: str) -> Any:
    return client.post(
        "/chat-attachments",
        data={"pet_id": pet_id},
        files={"file": ("zampa.png", PNG_BYTES, "application/octet-stream")},
    )


def test_a_successful_upload_is_counted(client: TestClient) -> None:
    pet_id = _pet(client)

    assert _upload(client, pet_id).status_code == 200

    assert _used("vision") == 1


# --- the client leaving, and what is final -------------------------------------------
#
# Whoever hangs up gets nothing back: the work goes on in its thread, the answer is stored and
# can be read from the conversation, so a refund would be a free question. The service itself
# settles the count: given back if it fails through our fault, final once the result is stored.


def test_a_client_that_hangs_up_keeps_what_was_counted() -> None:
    budget = get_container().llm_budget

    async def leaves() -> None:
        budget.admit_feature(owner_id=OWNER, kind="summary", limit=10)
        raise asyncio.CancelledError

    app.add_api_route("/__qa_client_leaves", leaves, methods=["GET"])
    try:
        with pytest.raises(BaseException):  # noqa: B017, PT011 - the cancellation reaches the client
            TestClient(app).get("/__qa_client_leaves")
    finally:
        app.router.routes.pop()

    assert _used("summary") == 1  # nothing in the middle gives it back


def _message(pet_id: str, text: str = "Mangia poco", **extra: Any) -> SendChatMessageInput:
    return SendChatMessageInput(owner_id=OWNER, pet_id=pet_id, user_message=text, **extra)


def test_a_question_whose_answer_is_stored_after_the_client_left_stays_counted(
    client: TestClient,
) -> None:
    pet_id = _pet(client)
    container = get_container()

    with access_token_context("a-token"):
        container.send_chat_message_service().execute(_message(pet_id))
        # The answer is stored: the use is final, nothing can give it back any more.
        assert container.llm_budget.refund_request_quota_uses() == 0

    assert _used("messages") == 1


def test_a_failure_after_the_client_left_is_given_back_by_the_service_itself(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    pet_id = _pet(client)
    container = get_container()
    budget = container.llm_budget

    def counted_then_broken(*_: object, **__: object) -> None:
        budget.admit(owner_id=OWNER, models=["demo-model"], user_daily_limit=10)
        raise RuntimeError("database exploded")

    monkeypatch.setattr(container.chat_orchestrator, "answer", counted_then_broken)

    with access_token_context("a-token"), pytest.raises(RuntimeError):
        container.send_chat_message_service().execute(_message(pet_id))

    assert _used("messages") == 0  # no middleware, no HTTP: the service settled it


def test_an_error_that_is_the_owners_own_keeps_the_use(client: TestClient) -> None:
    pet_id = _pet(client)
    container = get_container()

    with access_token_context("a-token"):
        container.llm_budget.admit_feature(owner_id=OWNER, kind="vision", limit=10)
        with pytest.raises(ValidationError), refund_if_our_failure(container.llm_budget):
            raise ValidationError("unsupported_attachment_type")

    assert _used("vision") == 1
    assert pet_id


def test_a_500_after_the_answer_was_stored_stays_counted(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    pet_id = _pet(client)

    def broken_response(*_: object, **__: object) -> None:
        raise RuntimeError("could not build the response")

    monkeypatch.setattr("apps.api.routes.chat.public_message", broken_response)

    response = _ask(client, pet_id)

    assert response.status_code == 500
    assert _used("messages") == 1  # the answer exists: the question is spent


def test_the_same_message_twice_at_once_is_counted_once(client: TestClient) -> None:
    pet_id = _pet(client)
    results: list[int] = []

    def send() -> None:
        own = TestClient(app, raise_server_exceptions=False)
        response = own.post(
            "/chat",
            json={
                "pet_id": pet_id,
                "user_message": "Mangia poco da due giorni",
                "client_message_id": "same-message-1",
            },
        )
        results.append(response.status_code)

    threads = [threading.Thread(target=send) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=60)

    assert results == [200, 200]
    assert _used("messages") == 1


@pytest.mark.parametrize(
    ("error", "ours"),
    [
        (RuntimeError("bug"), True),
        (ProviderError("Anthropic request failed with status 503"), True),
        (TimeoutError(), True),
        (ValidationError("not found"), False),
        (QuotaExceededError("vision", limit=1, retry_after_seconds=1, message="x"), False),
        (AuthenticationError("no"), False),
        (asyncio.CancelledError(), False),  # the client leaving is not a failure
    ],
)
def test_which_errors_are_ours(error: BaseException, ours: bool) -> None:
    assert is_our_failure(error) is ours


# --- the Supabase ledger and its SQL ----------------------------------------------------


def test_the_supabase_ledger_gives_back_through_the_new_function() -> None:
    from datetime import date

    from packages.infrastructure.persistence.supabase.supabase_repositories import (
        SupabaseLlmUsageRepository,
    )

    calls: list[tuple[str, dict[str, Any]]] = []

    class _Rpc:
        data = 3

        def execute(self) -> _Rpc:
            return self

    class _Client:
        def rpc(self, name: str, params: dict[str, Any]) -> _Rpc:
            calls.append((name, params))
            return _Rpc()

    client: Any = _Client()
    repository = SupabaseLlmUsageRepository(client)

    total = repository.remove_user_usage("owner-1", date(2026, 11, 23), "vision")

    assert total == 3
    assert calls == [
        (
            "chat_user_daily_usage_remove_kind",
            {"p_owner_id": "owner-1", "p_day": "2026-11-23", "p_kind": "vision"},
        )
    ]


def test_the_refund_sql_is_idempotent_never_goes_below_zero_and_is_for_the_backend_only() -> None:
    from pathlib import Path

    sql = Path("scripts/setup/chat_usage_refund.sql").read_text(encoding="utf-8").lower()

    assert "create or replace function public.chat_user_daily_usage_remove_kind" in sql
    assert sql.count("greatest(") == 6  # one per counter: never below zero
    assert "revoke all on function public.chat_user_daily_usage_remove_kind" in sql
    assert "to service_role" in sql
    assert "from public, anon, authenticated" in sql
    assert "unknown usage kind" in sql
    assert "add column if not exists sonnet" in sql and "add column if not exists followup" in sql
