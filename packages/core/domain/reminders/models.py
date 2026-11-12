from datetime import date

from pydantic import BaseModel, Field

from packages.core.domain.common.entity import new_id


class Reminder(BaseModel):
    id: str = Field(default_factory=new_id)
    owner_id: str
    pet_id: str
    title: str
    due_date: date
    notes: str | None = None
    # Written by the mobile app (reminders_repository.dart): "spot",
    # "recurring" or "course" (a therapy lasting course_duration_days).
    kind: str | None = None
    course_duration_days: int | None = None
    is_done: bool = False
