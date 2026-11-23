from pydantic import BaseModel

from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.domain.reminders.models import Reminder


class ListRemindersInput(BaseModel):
    owner_id: str


class ListRemindersOutput(BaseModel):
    reminders: list[Reminder]


class ListRemindersService:
    def __init__(self, repository: ReminderRepository) -> None:
        self._repository = repository

    def execute(self, data: ListRemindersInput) -> ListRemindersOutput:
        # Soonest first, as the app shows them; the id breaks ties so the order is stable.
        reminders = sorted(
            self._repository.list_by_owner(data.owner_id),
            key=lambda reminder: (reminder.due_date, reminder.id),
        )
        return ListRemindersOutput(reminders=reminders)
