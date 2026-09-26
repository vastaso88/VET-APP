from datetime import datetime

from pydantic import BaseModel

from packages.core.application.ports.local_activity_repository import LocalActivityRepository
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.local_activity.models import (
    LocalActivity,
    LocalActivityKind,
    LocalActivitySource,
)


class CreateLocalActivityInput(BaseModel):
    kind: LocalActivityKind
    title: str
    location: Coordinates
    description: str | None = None
    category: str | None = None
    address_label: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    source: LocalActivitySource = "user_submitted"
    submitted_by_owner_id: str | None = None


class CreateLocalActivityOutput(BaseModel):
    activity: LocalActivity


class CreateLocalActivityService:
    def __init__(self, repository: LocalActivityRepository) -> None:
        self._repository = repository

    def execute(self, data: CreateLocalActivityInput) -> CreateLocalActivityOutput:
        activity = LocalActivity(**data.model_dump())
        return CreateLocalActivityOutput(activity=self._repository.save(activity))
