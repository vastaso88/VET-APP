from datetime import date, timedelta

from pydantic import BaseModel

from packages.core.application.ports.event_submission_repository import (
    EventSubmissionRepository,
)
from packages.core.domain.common.entity import utc_now
from packages.core.domain.events.submission import (
    MAX_SUBMISSIONS_PER_DAY,
    EventSubmission,
    build_submission,
)
from packages.core.domain.localization import translate


class SubmissionLimitReachedError(Exception):
    """The owner already sent the daily maximum of suggestions. `str()` is the Italian sentence
    (`detail`); [message] is the same in the language of the request."""

    def __init__(self, maximum: int = MAX_SUBMISSIONS_PER_DAY) -> None:
        self.maximum = maximum
        super().__init__(self.message("it"))

    def message(self, language: str | None) -> str:
        return translate("event_submission_limit", language, max=self.maximum)


class SubmitEventInput(BaseModel):
    owner_id: str
    title: str
    event_type: str
    starts_on: date
    ends_on: date
    city: str
    source_url: str
    country: str | None = None
    province_code: str | None = None
    region: str | None = None
    venue_name: str | None = None


class SubmitEventService:
    """Puts a user's suggestion in the moderation queue. Nothing reaches the
    public list from here."""

    def __init__(self, repository: EventSubmissionRepository) -> None:
        self._repository = repository

    def execute(self, data: SubmitEventInput) -> EventSubmission:
        submission = build_submission(**data.model_dump())
        since = utc_now() - timedelta(days=1)
        if self._repository.count_since(data.owner_id, since) >= MAX_SUBMISSIONS_PER_DAY:
            raise SubmissionLimitReachedError(MAX_SUBMISSIONS_PER_DAY)
        self._repository.add(submission)
        return submission
