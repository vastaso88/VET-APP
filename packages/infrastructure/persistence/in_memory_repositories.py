from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.domain.consent.models import AccountConsents
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.dog_walk.models import WalkSession
from packages.core.domain.geo.models import UserLocation
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.reminders.models import Reminder


class InMemoryPetProfileRepository(PetProfileRepository):
    def __init__(self) -> None:
        self._items: dict[str, PetProfile] = {}

    def save(self, pet_profile: PetProfile) -> PetProfile:
        self._items[pet_profile.id] = pet_profile
        return pet_profile

    def get(self, pet_id: str) -> PetProfile | None:
        return self._items.get(pet_id)

    def list_by_owner(self, owner_id: str) -> list[PetProfile]:
        return [item for item in self._items.values() if item.owner_id == owner_id]


class InMemoryConversationRepository(ConversationRepository):
    def __init__(self) -> None:
        self._items: dict[str, Conversation] = {}

    def save(self, conversation: Conversation) -> Conversation:
        self._items[conversation.id] = conversation
        return conversation

    def get(self, conversation_id: str) -> Conversation | None:
        return self._items.get(conversation_id)

    def list_by_owner(self, owner_id: str) -> list[Conversation]:
        return [item for item in self._items.values() if item.owner_id == owner_id]

    def list_by_pet(self, pet_id: str) -> list[Conversation]:
        return [item for item in self._items.values() if item.pet_id == pet_id]

    def delete(self, conversation_id: str) -> None:
        self._items.pop(conversation_id, None)


class InMemoryReminderRepository(ReminderRepository):
    def __init__(self) -> None:
        self._items: list[Reminder] = []

    def save(self, reminder: Reminder) -> Reminder:
        self._items.append(reminder)
        return reminder

    def list_by_owner(self, owner_id: str) -> list[Reminder]:
        return [item for item in self._items if item.owner_id == owner_id]


class InMemoryClinicalEventRepository(ClinicalEventRepository):
    def __init__(self, seed: list[ClinicalEvent] | None = None) -> None:
        self._items: list[ClinicalEvent] = list(seed or [])

    def save(self, event: ClinicalEvent) -> ClinicalEvent:
        self._items.append(event)
        return event

    def list_by_pet(self, pet_id: str) -> list[ClinicalEvent]:
        return [item for item in self._items if item.pet_id == pet_id]


class InMemoryAccountConsentsRepository(AccountConsentsRepository):
    def __init__(self) -> None:
        self._items: dict[str, AccountConsents] = {}

    def get(self, owner_id: str) -> AccountConsents | None:
        return self._items.get(owner_id)

    def save(self, account_consents: AccountConsents) -> AccountConsents:
        self._items[account_consents.owner_id] = account_consents
        return account_consents


class InMemoryUserLocationRepository(UserLocationRepository):
    def __init__(self) -> None:
        self._items: dict[str, UserLocation] = {}

    def get(self, owner_id: str) -> UserLocation | None:
        return self._items.get(owner_id)

    def save(self, user_location: UserLocation) -> UserLocation:
        self._items[user_location.owner_id] = user_location
        return user_location


class InMemoryDogWalkRepository(DogWalkRepository):
    def __init__(self) -> None:
        self._items: dict[str, WalkSession] = {}

    def save(self, walk: WalkSession) -> WalkSession:
        self._items[walk.id] = walk
        return walk

    def get(self, walk_id: str) -> WalkSession | None:
        return self._items.get(walk_id)

    def list_by_owner(self, owner_id: str) -> list[WalkSession]:
        return [item for item in self._items.values() if item.owner_id == owner_id]
