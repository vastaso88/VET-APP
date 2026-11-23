from collections.abc import Iterator
from datetime import UTC, date, datetime

import pytest

from packages.core.application.services import create_reminder as create_reminder_module
from packages.core.application.services.create_reminder import (
    CreateReminderInput,
    CreateReminderService,
)
from packages.core.application.services.list_reminders import (
    ListRemindersInput,
    ListRemindersService,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.reminders.models import Reminder
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
)
from packages.shared.errors.base import ValidationError
from packages.shared.user_clock import reset_utc_offset_minutes, set_utc_offset_minutes

# 24 November 2026, 00:30 in Rome (UTC+1) = 23 November 23:30 UTC.
NOW = datetime(2026, 11, 23, 23, 30, tzinfo=UTC)


@pytest.fixture(autouse=True)
def _fixed_now(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    monkeypatch.setattr(create_reminder_module, "utc_now", lambda: NOW)
    yield


def _service() -> tuple[CreateReminderService, InMemoryReminderRepository]:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    reminders = InMemoryReminderRepository()
    return CreateReminderService(reminders, pet_repository), reminders


def _create(service: CreateReminderService, title: str, due: date) -> Reminder:
    return service.execute(
        CreateReminderInput(owner_id="user-1", pet_id="pet-1", title=title, due_date=due)
    ).reminder


def test_create_reminder() -> None:
    service, _ = _service()

    assert _create(service, "Vaccino", date(2026, 12, 1)).title == "Vaccino"


def test_title_is_kept_without_the_spaces_around_it() -> None:
    service, _ = _service()

    assert _create(service, "  Vaccino  ", date(2026, 12, 1)).title == "Vaccino"


@pytest.mark.parametrize("title", ["", " ", "   ", "\t\n"])
def test_empty_or_blank_title_is_refused_and_nothing_is_saved(title: str) -> None:
    service, reminders = _service()

    with pytest.raises(ValidationError, match="reminder_title_required"):
        _create(service, title, date(2026, 12, 1))
    assert reminders.list_by_owner("user-1") == []


def test_a_past_date_is_refused_at_creation() -> None:
    service, reminders = _service()

    with pytest.raises(ValidationError, match="reminder_date_in_past"):
        _create(service, "Vaccino", date(2026, 4, 1))
    assert reminders.list_by_owner("user-1") == []


def test_today_is_allowed_on_the_owners_own_clock() -> None:
    # Rome: it is already 24 November there, yesterday's 23rd is gone.
    token = set_utc_offset_minutes(60)
    try:
        service, _ = _service()
        assert _create(service, "Oggi", date(2026, 11, 24)).due_date == date(2026, 11, 24)
        with pytest.raises(ValidationError, match="reminder_date_in_past"):
            _create(service, "Ieri", date(2026, 11, 23))
    finally:
        reset_utc_offset_minutes(token)


def test_a_phone_behind_utc_can_still_use_its_own_today() -> None:
    # New York (UTC-5): at 23:30 UTC it is 18:30 on the 23rd, which is still today.
    token = set_utc_offset_minutes(-300)
    try:
        service, _ = _service()
        assert _create(service, "Oggi", date(2026, 11, 23)).due_date == date(2026, 11, 23)
        with pytest.raises(ValidationError, match="reminder_date_in_past"):
            _create(service, "Ieri", date(2026, 11, 22))
    finally:
        reset_utc_offset_minutes(token)


def test_without_the_offset_a_day_that_may_still_be_today_somewhere_is_not_refused() -> None:
    # No header (a client that does not send it): the owner's zone is unknown, so only a
    # day that is over everywhere is refused.
    service, _ = _service()

    assert _create(service, "Forse oggi", date(2026, 11, 23)).due_date == date(2026, 11, 23)
    with pytest.raises(ValidationError, match="reminder_date_in_past"):
        _create(service, "Passato", date(2026, 11, 22))


def test_the_list_comes_soonest_first_whatever_the_order_of_saving() -> None:
    reminders = InMemoryReminderRepository()
    for index, due in enumerate([date(2026, 12, 14), date(2026, 11, 30), date(2026, 11, 24)]):
        reminders.save(
            Reminder(id=f"r{index}", owner_id="user-1", pet_id="pet-1", title="x", due_date=due)
        )
    reminders.save(
        Reminder(
            id="other", owner_id="user-2", pet_id="pet-2", title="x", due_date=date(2026, 1, 1)
        )
    )

    result = ListRemindersService(reminders).execute(ListRemindersInput(owner_id="user-1"))

    assert [reminder.due_date for reminder in result.reminders] == [
        date(2026, 11, 24),
        date(2026, 11, 30),
        date(2026, 12, 14),
    ]


def test_same_day_reminders_keep_a_stable_order() -> None:
    reminders = InMemoryReminderRepository()
    for rid in ["b", "a", "c"]:
        reminders.save(
            Reminder(
                id=rid, owner_id="user-1", pet_id="pet-1", title=rid, due_date=date(2026, 12, 1)
            )
        )

    result = ListRemindersService(reminders).execute(ListRemindersInput(owner_id="user-1"))

    assert [reminder.id for reminder in result.reminders] == ["a", "b", "c"]
