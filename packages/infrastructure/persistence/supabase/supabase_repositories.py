from datetime import date, datetime
from typing import TYPE_CHECKING, Any

from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.domain.conversation.models import Conversation
from packages.core.domain.medical_record.models import ClinicalEvent
from packages.core.domain.pet_profile.models import PetProfile
from packages.core.domain.reminders.models import Reminder

if TYPE_CHECKING:
    from supabase import Client


def _serialize_payload(payload: dict[str, Any]) -> dict[str, Any]:
    serialized: dict[str, Any] = {}
    for key, value in payload.items():
        if isinstance(value, (datetime, date)):
            serialized[key] = value.isoformat()
        else:
            serialized[key] = value
    return serialized


class SupabasePetProfileRepository(PetProfileRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "pet_profiles"

    def save(self, pet_profile: PetProfile) -> PetProfile:
        payload = _serialize_payload(pet_profile.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return pet_profile

    def get(self, pet_id: str) -> PetProfile | None:
        response = self._client.table(self._table).select("*").eq("id", pet_id).limit(1).execute()
        if not response.data:
            return None
        return PetProfile.model_validate(response.data[0])

    def list_by_owner(self, owner_id: str) -> list[PetProfile]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [PetProfile.model_validate(item) for item in response.data or []]


class SupabaseConversationRepository(ConversationRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "conversations"

    def save(self, conversation: Conversation) -> Conversation:
        payload = _serialize_payload(conversation.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return conversation

    def get(self, conversation_id: str) -> Conversation | None:
        response = self._client.table(self._table).select("*").eq("id", conversation_id).limit(1).execute()
        if not response.data:
            return None
        return Conversation.model_validate(response.data[0])

    def list_by_owner(self, owner_id: str) -> list[Conversation]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [Conversation.model_validate(item) for item in response.data or []]


class SupabaseReminderRepository(ReminderRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "reminders"

    def save(self, reminder: Reminder) -> Reminder:
        payload = _serialize_payload(reminder.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return reminder

    def list_by_owner(self, owner_id: str) -> list[Reminder]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [Reminder.model_validate(item) for item in response.data or []]


class SupabaseClinicalEventRepository(ClinicalEventRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "clinical_events"

    def list_by_pet(self, pet_id: str) -> list[ClinicalEvent]:
        response = self._client.table(self._table).select("*").eq("pet_id", pet_id).execute()
        return [ClinicalEvent.model_validate(item) for item in response.data or []]
