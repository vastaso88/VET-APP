from datetime import date

from packages.core.application.services.create_reminder import (
    CreateReminderInput,
    CreateReminderService,
)
from packages.core.domain.pet_profile.models import PetProfile
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
)


def test_create_reminder() -> None:
    pet_repository = InMemoryPetProfileRepository()
    pet_repository.save(PetProfile(id="pet-1", owner_id="user-1", name="Milo", species="dog"))
    service = CreateReminderService(InMemoryReminderRepository(), pet_repository)

    result = service.execute(
        CreateReminderInput(
            owner_id="user-1",
            pet_id="pet-1",
            title="Vaccino",
            due_date=date(2026, 4, 1),
        )
    )

    assert result.reminder.title == "Vaccino"
