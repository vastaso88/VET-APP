"""Privacy posture of chat response reports
(docs/compliance/07_contributi_utenti.md): pseudonymous reporter, anonymized
and clipped text, 12-month retention, erasure, review restricted."""

from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from apps.api.dependencies.container import get_container
from apps.api.main import app
from packages.core.application.ports.pii_anonymizer import (
    PiiAnonymizationRequest,
    PiiAnonymizationResult,
)
from packages.core.application.services.maintain_chat_response_reports import (
    ChatResponseReportMaintenanceService,
)
from packages.core.application.services.report_chat_response import (
    MAX_DETAILS_CHARS,
    MAX_REPORTED_ANSWER_CHARS,
    ReportChatResponseInput,
    ReportChatResponseService,
)
from packages.core.domain.conversation.models import ChatMessage, Conversation
from packages.core.domain.feedback.models import ChatResponseReport
from packages.core.domain.feedback.pseudonym import reporter_ref
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatResponseReportRepository,
    InMemoryConversationRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer

SALT = "test-salt"
NOW = datetime(2026, 10, 3, tzinfo=UTC)


class PhoneRedactingAnonymizer:
    def anonymize(self, request: PiiAnonymizationRequest) -> PiiAnonymizationResult:
        return PiiAnonymizationResult(
            anonymized_text=request.text.replace("3331234567", "<TELEFONO>"), redaction_count=1
        )


def _conversation(repository: InMemoryConversationRepository, answer: str) -> Conversation:
    return repository.save(
        Conversation(
            owner_id="owner-1",
            pet_id="pet-1",
            title="Chat",
            messages=[
                ChatMessage(role="user", content="Domanda"),
                ChatMessage(role="assistant", content=answer),
            ],
        )
    )


def _report(
    answer: str = "Risposta", details: str | None = None
) -> tuple[ChatResponseReport, InMemoryChatResponseReportRepository, ReportChatResponseService]:
    conversations = InMemoryConversationRepository()
    conversation = _conversation(conversations, answer)
    reports = InMemoryChatResponseReportRepository()
    service = ReportChatResponseService(conversations, reports, PhoneRedactingAnonymizer(), SALT)
    result = service.execute(
        ReportChatResponseInput(
            reporter_owner_id="owner-1",
            conversation_id=conversation.id,
            message_id=conversation.messages[1].id,
            details=details,
        )
    )
    return result.report, reports, service


def test_the_reporter_is_stored_only_as_a_pseudonym() -> None:
    report, _, _ = _report()

    assert report.reporter_owner_id is None
    assert report.reporter_ref == reporter_ref("owner-1", SALT)
    assert "owner-1" not in report.model_dump_json()


def test_the_pseudonym_is_stable_and_depends_on_the_secret() -> None:
    assert reporter_ref("owner-1", SALT) == reporter_ref("owner-1", SALT)
    assert reporter_ref("owner-1", SALT) != reporter_ref("owner-2", SALT)
    assert reporter_ref("owner-1", SALT) != reporter_ref("owner-1", "another-secret")


def test_stored_text_is_anonymized_and_clipped() -> None:
    report, _, _ = _report(
        answer="Chiama il 3331234567. " + "a" * (MAX_REPORTED_ANSWER_CHARS * 2),
        details="Il mio numero è 3331234567 " + "b" * (MAX_DETAILS_CHARS * 2),
    )

    assert "3331234567" not in report.reported_answer
    assert "<TELEFONO>" in report.reported_answer
    assert len(report.reported_answer) <= MAX_REPORTED_ANSWER_CHARS + 1
    assert report.details is not None
    assert "3331234567" not in report.details
    assert len(report.details) <= MAX_DETAILS_CHARS + 1


def test_reporting_the_same_reply_twice_does_not_create_a_second_report() -> None:
    conversations = InMemoryConversationRepository()
    conversation = _conversation(conversations, "Risposta")
    reports = InMemoryChatResponseReportRepository()
    service = ReportChatResponseService(conversations, reports, NoopPiiAnonymizer(), SALT)
    data = ReportChatResponseInput(
        reporter_owner_id="owner-1",
        conversation_id=conversation.id,
        message_id=conversation.messages[1].id,
    )

    first = service.execute(data).report
    second = service.execute(data).report

    assert second.id == first.id
    assert len(reports.list_all()) == 1


def _stored(
    repository: InMemoryChatResponseReportRepository, **fields: object
) -> ChatResponseReport:
    base: dict[str, object] = {
        "conversation_id": "c1",
        "message_id": "m1",
        "pet_id": "p1",
        "reported_answer": "answer",
        "reporter_ref": reporter_ref("owner-1", SALT),
    }
    base.update(fields)
    return repository.save(ChatResponseReport(**base))  # type: ignore[arg-type]


def test_retention_deletes_reports_a_year_after_the_outcome_and_keeps_only_a_counter() -> None:
    repository = InMemoryChatResponseReportRepository()
    expired = _stored(
        repository,
        status="resolved",
        reason="wrong_answer",
        created_at=NOW - timedelta(days=500),
        resolved_at=NOW - timedelta(days=366),
    )
    recent = _stored(repository, status="resolved", resolved_at=NOW - timedelta(days=30))
    still_open = _stored(repository, created_at=NOW - timedelta(days=900))

    result = ChatResponseReportMaintenanceService(repository, SALT).run(NOW)

    assert result.purged == 1
    remaining = {report.id for report in repository.list_all()}
    assert remaining == {recent.id, still_open.id}
    counters = repository.list_counters()
    assert len(counters) == 1
    assert counters[0].period == expired.created_at.strftime("%Y-%m")
    assert (counters[0].reason, counters[0].status, counters[0].total) == (
        "wrong_answer",
        "resolved",
        1,
    )


def test_maintenance_is_idempotent() -> None:
    repository = InMemoryChatResponseReportRepository()
    _stored(repository, status="wont_fix", resolved_at=NOW - timedelta(days=400))
    service = ChatResponseReportMaintenanceService(repository, SALT)

    service.run(NOW)
    second = service.run(NOW)

    assert second.purged == 0
    assert repository.list_counters()[0].total == 1


def test_maintenance_pseudonymizes_legacy_rows_that_stored_the_owner_id() -> None:
    repository = InMemoryChatResponseReportRepository()
    legacy = _stored(repository, reporter_ref=None, reporter_owner_id="owner-1")

    result = ChatResponseReportMaintenanceService(repository, SALT).run(NOW)

    converted = repository.get(legacy.id)
    assert result.legacy_pseudonymized == 1
    assert converted is not None
    assert converted.reporter_owner_id is None
    assert converted.reporter_ref == reporter_ref("owner-1", SALT)


def test_erasure_removes_only_that_owners_reports_including_legacy_ones() -> None:
    repository = InMemoryChatResponseReportRepository()
    _stored(repository)
    _stored(repository, reporter_ref=None, reporter_owner_id="owner-1")
    other = _stored(repository, reporter_ref=reporter_ref("owner-2", SALT))

    erased = ChatResponseReportMaintenanceService(repository, SALT).erase_for_owner("owner-1")

    assert erased == 2
    assert [report.id for report in repository.list_all()] == [other.id]
    assert repository.list_counters() == []


# --- API: nobody reads other people's reports -------------------------------


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def _report_through_api(client: TestClient) -> dict[str, object]:
    created = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()
    pet_id = created["pet_profile"]["id"]
    chat = client.post("/chat", json={"pet_id": pet_id, "user_message": "ciao"}).json()
    response = client.post(
        "/chat-response-reports",
        json={
            "conversation_id": chat["conversation"]["id"],
            "message_id": chat["reply"]["id"],
            "reason": "wrong_answer",
        },
    )
    assert response.status_code == 200
    report: dict[str, object] = response.json()["report"]
    return report


def test_api_never_returns_the_reporter_and_blocks_review_for_non_developers(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    container = get_container()
    monkeypatch.setattr(container, "developer_emails", frozenset())

    report = _report_through_api(client)

    assert "reporter_ref" not in report
    assert "reporter_owner_id" not in report
    assert client.get("/chat-response-reports").status_code == 401
    assert (
        client.put(
            f"/chat-response-reports/{report['id']}/resolve", json={"status": "resolved"}
        ).status_code
        == 401
    )
    assert client.post("/chat-response-reports/maintenance").status_code == 401


def test_api_lets_a_developer_review_and_an_owner_erase_their_own_reports(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    container = get_container()
    email = container.auth_provider.get_current_user().email.strip().lower()
    monkeypatch.setattr(container, "developer_emails", frozenset({email}))
    report = _report_through_api(client)

    listed = client.get("/chat-response-reports")

    assert listed.status_code == 200
    assert any(item["id"] == report["id"] for item in listed.json()["reports"])
    assert all("reporter_ref" not in item for item in listed.json()["reports"])
    assert client.post("/chat-response-reports/maintenance").status_code == 200

    erased = client.delete("/chat-response-reports/mine")

    assert erased.status_code == 200
    assert erased.json()["erased"] >= 1
    remaining = client.get("/chat-response-reports").json()["reports"]
    assert all(item["id"] != report["id"] for item in remaining)
