from packages.core.application.services.list_chat_response_reports import (
    ListChatResponseReportsInput,
    ListChatResponseReportsService,
)
from packages.core.domain.feedback.models import ChatResponseReport
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryChatResponseReportRepository,
)


def test_lists_every_report_when_no_status_filter_is_given() -> None:
    repository = InMemoryChatResponseReportRepository()
    repository.save(
        ChatResponseReport(
            conversation_id="c1", message_id="m1", pet_id="p1", reporter_owner_id="o1",
            reported_answer="answer", status="reported",
        )
    )
    repository.save(
        ChatResponseReport(
            conversation_id="c2", message_id="m2", pet_id="p1", reporter_owner_id="o2",
            reported_answer="answer", status="resolved",
        )
    )
    service = ListChatResponseReportsService(repository)

    result = service.execute(ListChatResponseReportsInput())

    assert len(result.reports) == 2


def test_filters_by_status() -> None:
    repository = InMemoryChatResponseReportRepository()
    repository.save(
        ChatResponseReport(
            conversation_id="c1", message_id="m1", pet_id="p1", reporter_owner_id="o1",
            reported_answer="answer", status="reported",
        )
    )
    repository.save(
        ChatResponseReport(
            conversation_id="c2", message_id="m2", pet_id="p1", reporter_owner_id="o2",
            reported_answer="answer", status="resolved",
        )
    )
    service = ListChatResponseReportsService(repository)

    result = service.execute(ListChatResponseReportsInput(status="resolved"))

    assert len(result.reports) == 1
    assert result.reports[0].status == "resolved"
