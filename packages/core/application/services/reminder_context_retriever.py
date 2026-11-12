from datetime import date, timedelta

from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.domain.reminders.models import Reminder

# Reminders outside this window around today are not "active and
# relevant" for a chat turn: an old overdue one is stale, a far-future one
# says nothing about the pet's situation now.
OVERDUE_WINDOW = timedelta(days=14)
UPCOMING_WINDOW = timedelta(days=60)


class ReminderContextRetriever:
    """The pet's active, currently relevant reminders as a short text block
    for the chat prompt — e.g. an ongoing antibiotic course changes what
    sensible advice looks like. Reminders are the owner's own care
    schedule (not clinical documents), so no medical-record consent
    applies; the caller still anonymizes the text before it leaves for
    the LLM provider.
    """

    def __init__(self, repository: ReminderRepository, *, max_entries: int = 5) -> None:
        self._repository = repository
        self._max_entries = max_entries

    def summarize_for_pet(self, owner_id: str, pet_id: str, today: date) -> str | None:
        relevant = [
            reminder
            for reminder in self._repository.list_by_owner(owner_id)
            if reminder.pet_id == pet_id
            and not reminder.is_done
            and self._is_relevant(reminder, today)
        ]
        if not relevant:
            return None
        relevant.sort(key=lambda reminder: reminder.due_date)
        shown = relevant[: self._max_entries]
        return "\n".join(self._format(reminder, today) for reminder in shown)

    @staticmethod
    def _course_end(reminder: Reminder) -> date | None:
        if reminder.kind != "course" or not reminder.course_duration_days:
            return None
        return reminder.due_date + timedelta(days=reminder.course_duration_days)

    def _is_relevant(self, reminder: Reminder, today: date) -> bool:
        course_end = self._course_end(reminder)
        if course_end is not None and reminder.due_date <= today <= course_end:
            return True
        return today - OVERDUE_WINDOW <= reminder.due_date <= today + UPCOMING_WINDOW

    def _format(self, reminder: Reminder, today: date) -> str:
        course_end = self._course_end(reminder)
        if course_end is not None and reminder.due_date <= today <= course_end:
            when = (
                f"terapia in corso dal {reminder.due_date.isoformat()} al {course_end.isoformat()}"
            )
        elif reminder.due_date < today:
            when = f"scaduto il {reminder.due_date.isoformat()}"
        else:
            when = f"previsto per il {reminder.due_date.isoformat()}"
        notes = f" — {reminder.notes}" if reminder.notes else ""
        return f"- {reminder.title} ({when}){notes}"
