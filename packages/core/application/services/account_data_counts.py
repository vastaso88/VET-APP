import logging

from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.domain.subscription.retention_notices import AccountDataCounts

logger = logging.getLogger(__name__)


class AccountDataCounter:
    """Counts what an account really holds, for the e-mails that quote it
    ("3 animali, 12 documenti"). Read-only. A failed read gives None, never a
    guess, and nothing about the counts or the owner is logged."""

    def __init__(
        self,
        pets: PetProfileRepository,
        clinical_events: ClinicalEventRepository,
        reminders: ReminderRepository,
        walks: DogWalkRepository,
    ) -> None:
        self._pets = pets
        self._clinical_events = clinical_events
        self._reminders = reminders
        self._walks = walks

    def count(self, owner_id: str) -> AccountDataCounts | None:
        try:
            pets = self._pets.list_by_owner(owner_id)
            documents = sum(len(self._clinical_events.list_by_pet(pet.id)) for pet in pets)
            reminders = len(self._reminders.list_by_owner(owner_id))
            # A discarded walk is not something the owner sees or keeps.
            walks = sum(
                1 for walk in self._walks.list_by_owner(owner_id) if walk.status != "discarded"
            )
        except Exception:  # noqa: BLE001 - unknown counts must stay unknown
            logger.warning("could not count the data of an account", exc_info=False)
            return None
        return AccountDataCounts(
            animals=len(pets), documents=documents, reminders=reminders, walks=walks
        )
