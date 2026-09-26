from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id, utc_now
from packages.core.domain.geo.models import Coordinates

# "event" covers fairs/adoption days/vaccination days; "service" covers
# fixed venues like a vet clinic or pet store - both answer the same
# "cosa c'è vicino a me" question, so they share one entity (see
# docs/maps/, "Attività attorno a te" / "Eventi nei dintorni").
LocalActivityKind = Literal["event", "service"]
LocalActivitySource = Literal["user_submitted", "seeded"]
LocalActivityStatus = Literal["active", "removed"]


class LocalActivity(BaseModel):
    id: str = Field(default_factory=new_id)
    kind: LocalActivityKind
    title: str
    description: str | None = None
    category: str | None = None
    # Never fuzzed: public venues/events that already advertise their own
    # location, unlike marketplace listings (see geo.models.fuzz_coordinates).
    location: Coordinates
    address_label: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    source: LocalActivitySource = "user_submitted"
    submitted_by_owner_id: str | None = None
    status: LocalActivityStatus = "active"
    report_count: int = 0
    created_at: datetime = Field(default_factory=utc_now)
