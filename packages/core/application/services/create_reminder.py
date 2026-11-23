from datetime import date

from pydantic import BaseModel

from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.domain.llm_usage.models import owner_day, utc_now
from packages.core.domain.pet_profile.memorial import ensure_not_in_memories
from packages.core.domain.reminders.models import Reminder
from packages.shared.errors.base import ValidationError
from packages.shared.user_clock import current_utc_offset_minutes

# Without the phone's offset (it arrives as 0, like for a phone on UTC) the owner's zone
# is unknown: the earliest day anywhere on earth (UTC-12) is the limit, so nobody is
# told "that day has passed" while it is still today where they are.
_EARLIEST_LOCAL_OFFSET_MINUTES = -12 * 60


def first_allowed_day() -> date:
    """The earliest day a NEW reminder may fall on: today on the owner's own clock."""
    offset = current_utc_offset_minutes()
    return owner_day(utc_now(), offset if offset != 0 else _EARLIEST_LOCAL_OFFSET_MINUTES)


class CreateReminderInput(BaseModel):
    owner_id: str
    pet_id: str
    title: str
    due_date: date
    notes: str | None = None


class CreateReminderOutput(BaseModel):
    reminder: Reminder


class CreateReminderService:
    def __init__(
        self,
        repository: ReminderRepository,
        pet_profile_repository: PetProfileRepository,
    ) -> None:
        self._repository = repository
        self._pet_profile_repository = pet_profile_repository

    def execute(self, data: CreateReminderInput) -> CreateReminderOutput:
        pet_profile = self._pet_profile_repository.get(data.pet_id)
        if pet_profile is None or pet_profile.owner_id != data.owner_id:
            raise ValidationError("pet_profile not found")
        ensure_not_in_memories(pet_profile)
        title = data.title.strip()
        if not title:
            raise ValidationError("reminder_title_required: scrivi un titolo per il promemoria.")
        # Only a new reminder: an overdue one stays editable, and a recurring one moves
        # forward by itself, neither goes through here.
        if data.due_date < first_allowed_day():
            raise ValidationError("reminder_date_in_past: la data del promemoria è già passata.")
        reminder = Reminder(**{**data.model_dump(), "title": title})
        return CreateReminderOutput(reminder=self._repository.save(reminder))
