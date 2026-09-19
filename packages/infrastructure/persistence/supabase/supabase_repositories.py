from datetime import date, datetime
from typing import TYPE_CHECKING, Any, cast

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
from packages.core.domain.geo.models import Coordinates, UserLocation
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
        response = (
            self._client.table(self._table)
            .select("*")
            .eq("id", conversation_id)
            .limit(1)
            .execute()
        )
        if not response.data:
            return None
        return Conversation.model_validate(response.data[0])

    def list_by_owner(self, owner_id: str) -> list[Conversation]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [Conversation.model_validate(item) for item in response.data or []]

    def list_by_pet(self, pet_id: str) -> list[Conversation]:
        response = self._client.table(self._table).select("*").eq("pet_id", pet_id).execute()
        return [Conversation.model_validate(item) for item in response.data or []]

    def delete(self, conversation_id: str) -> None:
        self._client.table(self._table).delete().eq("id", conversation_id).execute()


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


class SupabaseAccountConsentsRepository(AccountConsentsRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "account_consents"

    def get(self, owner_id: str) -> AccountConsents | None:
        response = (
            self._client.table(self._table).select("*").eq("owner_id", owner_id).limit(1).execute()
        )
        if not response.data:
            return None
        return AccountConsents.model_validate(response.data[0])

    def save(self, account_consents: AccountConsents) -> AccountConsents:
        payload = _serialize_payload(account_consents.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return account_consents


def _user_location_to_row(user_location: UserLocation) -> dict[str, Any]:
    payload = _serialize_payload(user_location.model_dump(mode="json", exclude={"home", "current"}))
    if user_location.home is not None:
        payload["home_latitude"] = user_location.home.latitude
        payload["home_longitude"] = user_location.home.longitude
    if user_location.current is not None:
        payload["current_latitude"] = user_location.current.latitude
        payload["current_longitude"] = user_location.current.longitude
    return payload


def _row_to_user_location(row: dict[str, Any]) -> UserLocation:
    home = None
    if row.get("home_latitude") is not None and row.get("home_longitude") is not None:
        home = Coordinates(latitude=row["home_latitude"], longitude=row["home_longitude"])
    current = None
    if row.get("current_latitude") is not None and row.get("current_longitude") is not None:
        current = Coordinates(latitude=row["current_latitude"], longitude=row["current_longitude"])
    return UserLocation.model_validate({**row, "home": home, "current": current})


class SupabaseUserLocationRepository(UserLocationRepository):
    """user_locations stores latitude/longitude as flat columns (see
    scripts/setup/supabase_schema.sql), not the nested `Coordinates` shape
    the domain model uses - this repository is the flattening boundary."""

    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "user_locations"

    def get(self, owner_id: str) -> UserLocation | None:
        response = (
            self._client.table(self._table).select("*").eq("owner_id", owner_id).limit(1).execute()
        )
        if not response.data:
            return None
        return _row_to_user_location(cast(dict[str, Any], response.data[0]))

    def save(self, user_location: UserLocation) -> UserLocation:
        self._client.table(self._table).upsert(_user_location_to_row(user_location)).execute()
        return user_location


class SupabaseDogWalkRepository(DogWalkRepository):
    def __init__(self, client: Client) -> None:
        self._client = client
        self._table = "dog_walks"

    def save(self, walk: WalkSession) -> WalkSession:
        payload = _serialize_payload(walk.model_dump(mode="json"))
        self._client.table(self._table).upsert(payload).execute()
        return walk

    def get(self, walk_id: str) -> WalkSession | None:
        response = self._client.table(self._table).select("*").eq("id", walk_id).limit(1).execute()
        if not response.data:
            return None
        return WalkSession.model_validate(response.data[0])

    def list_by_owner(self, owner_id: str) -> list[WalkSession]:
        response = self._client.table(self._table).select("*").eq("owner_id", owner_id).execute()
        return [WalkSession.model_validate(item) for item in response.data or []]
