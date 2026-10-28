"""Account data export for local development (in-memory repositories).

Same shape as the Supabase exporter so the route, the app and the tests
see one contract; rows are the domain models serialised as JSON. Never
used when PERSISTENCE_BACKEND=supabase."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.account_exporter import AccountExport
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.ports.pet_condition_repository import PetConditionRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.application.ports.user_location_repository import UserLocationRepository


class InMemoryAccountExporter:
    def __init__(
        self,
        *,
        pet_profiles: PetProfileRepository,
        conversations: ConversationRepository,
        reminders: ReminderRepository,
        clinical_events: ClinicalEventRepository,
        pet_conditions: PetConditionRepository,
        account_consents: AccountConsentsRepository,
        user_locations: UserLocationRepository,
        dog_walks: DogWalkRepository,
        marketplace_listings: MarketplaceListingRepository,
    ) -> None:
        self._pet_profiles = pet_profiles
        self._conversations = conversations
        self._reminders = reminders
        self._clinical_events = clinical_events
        self._pet_conditions = pet_conditions
        self._account_consents = account_consents
        self._user_locations = user_locations
        self._dog_walks = dog_walks
        self._marketplace_listings = marketplace_listings

    def export_data(self, owner_id: str) -> AccountExport:
        pets = self._pet_profiles.list_by_owner(owner_id)
        data: dict[str, list[dict[str, Any]]] = {
            "pet_profiles": _dump(pets),
            "clinical_events": [
                row for pet in pets for row in _dump(self._clinical_events.list_by_pet(pet.id))
            ],
            "pet_conditions": [
                row for pet in pets for row in _dump(self._pet_conditions.list_by_pet(pet.id))
            ],
            "conversations": _dump(self._conversations.list_by_owner(owner_id)),
            "reminders": _dump(self._reminders.list_by_owner(owner_id)),
            "dog_walks": _dump(self._dog_walks.list_by_owner(owner_id)),
            "marketplace_listings": _dump(
                [
                    listing
                    for listing in self._marketplace_listings.list_active()
                    if listing.owner_id == owner_id
                ]
            ),
            "account_consents": _dump(
                [c for c in [self._account_consents.get(owner_id)] if c is not None]
            ),
            "user_locations": _dump(
                [loc for loc in [self._user_locations.get(owner_id)] if loc is not None]
            ),
        }
        return AccountExport(
            generated_at=datetime.now(UTC),
            owner_id=owner_id,
            account={"id": owner_id},
            data=data,
            notes=["local in-memory backend: no stored files, no usage counters"],
        )


def _dump(models: list[Any]) -> list[dict[str, Any]]:
    return [model.model_dump(mode="json") for model in models]
