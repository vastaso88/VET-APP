from datetime import date

from pydantic import BaseModel

from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.domain.reminders.models import Reminder
from packages.shared.errors.base import ValidationError


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
        reminder = Reminder(**data.model_dump())
        return CreateReminderOutput(reminder=self._repository.save(reminder))
