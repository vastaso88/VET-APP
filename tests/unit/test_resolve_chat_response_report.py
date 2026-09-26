import pytest

from packages.core.application.services.resolve_chat_response_report import (
    ResolveChatResponseReportInput,
    ResolveChatResponseReportService,
)
from packages.core.domain.feedback.models import ChatResponseReport
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatResponseReportRepository,
)
from packages.shared.errors.base import ValidationError


def test_resolving_sets_status_timestamp_and_credited_bug_ref() -> None:
    repository = InMemoryChatResponseReportRepository()
    report = repository.save(
        ChatResponseReport(
            conversation_id="c1", message_id="m1", pet_id="p1", reporter_owner_id="o1",
            reported_answer="answer",
        )
    )
    service = ResolveChatResponseReportService(repository)

    result = service.execute(
        ResolveChatResponseReportInput(
            report_id=report.id,
            status="resolved",
            resolution_note="Fixed the husbandry catalog gap",
            credited_bug_ref="commit-abc123",
        )
    )

    assert result.report.status == "resolved"
    assert result.report.resolved_at is not None
    assert result.report.credited_bug_ref == "commit-abc123"


def test_moving_to_under_review_does_not_set_resolved_at() -> None:
    repository = InMemoryChatResponseReportRepository()
    report = repository.save(
        ChatResponseReport(
            conversation_id="c1", message_id="m1", pet_id="p1", reporter_owner_id="o1",
            reported_answer="answer",
        )
    )
    service = ResolveChatResponseReportService(repository)

    result = service.execute(
        ResolveChatResponseReportInput(report_id=report.id, status="under_review")
    )

    assert result.report.status == "under_review"
    assert result.report.resolved_at is None


def test_wont_fix_does_not_set_a_credited_bug_ref_unless_given() -> None:
    repository = InMemoryChatResponseReportRepository()
    report = repository.save(
        ChatResponseReport(
            conversation_id="c1", message_id="m1", pet_id="p1", reporter_owner_id="o1",
            reported_answer="answer",
        )
    )
    service = ResolveChatResponseReportService(repository)

    result = service.execute(
        ResolveChatResponseReportInput(report_id=report.id, status="wont_fix")
    )

    assert result.report.status == "wont_fix"
    assert result.report.resolved_at is not None
    assert result.report.credited_bug_ref is None


def test_rejects_an_unknown_report_id() -> None:
    service = ResolveChatResponseReportService(InMemoryChatResponseReportRepository())

    with pytest.raises(ValidationError):
        service.execute(ResolveChatResponseReportInput(report_id="missing", status="resolved"))
