"""Repository builders for in-memory and Supabase persistence (QK-20, verbatim)."""

from packages.bootstrap.container_state import ContainerState
from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.local_activity_repository import LocalActivityRepository
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.ports.owner_contact_lookup import OwnerContactLookup
from packages.core.application.ports.pet_condition_repository import PetConditionRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.application.ports.user_device_repository import UserDeviceRepository
from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.application.ports.weight_measurement_repository import (
    WeightMeasurementRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
    InMemoryChatAttachmentRepository,
    InMemoryChatResponseReportRepository,
    InMemoryClinicalEventRepository,
    InMemoryConversationRepository,
    InMemoryDogWalkRepository,
    InMemoryLocalActivityRepository,
    InMemoryOwnerContactLookup,
    InMemoryPetConditionRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
    InMemorySubscriptionRepository,
    InMemoryUserDeviceRepository,
    InMemoryUserLocationRepository,
    InMemoryWeightMeasurementRepository,
)
from packages.infrastructure.storage.local_file_storage import LocalFileStorage


class PersistenceWiring(ContainerState):
    def _build_repositories(
        self,
    ) -> tuple[PetProfileRepository, ConversationRepository, ReminderRepository]:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseConversationRepository,
                    SupabasePetProfileRepository,
                    SupabaseReminderRepository,
                )

                client = build_supabase_client(self.settings)
                return (
                    SupabasePetProfileRepository(client),
                    SupabaseConversationRepository(client),
                    SupabaseReminderRepository(client),
                )
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return (
                        InMemoryPetProfileRepository(),
                        InMemoryConversationRepository(),
                        InMemoryReminderRepository(),
                    )
                raise
        return (
            InMemoryPetProfileRepository(),
            InMemoryConversationRepository(),
            InMemoryReminderRepository(),
        )

    def _build_clinical_event_repository(self) -> ClinicalEventRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseClinicalEventRepository,
                )

                return SupabaseClinicalEventRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryClinicalEventRepository()
                raise
        return InMemoryClinicalEventRepository()

    def _build_pet_condition_repository(self) -> PetConditionRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabasePetConditionRepository,
                )

                return SupabasePetConditionRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryPetConditionRepository()
                raise
        return InMemoryPetConditionRepository()

    def _build_account_consents_repository(self) -> AccountConsentsRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseAccountConsentsRepository,
                )

                return SupabaseAccountConsentsRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryAccountConsentsRepository()
                raise
        return InMemoryAccountConsentsRepository()

    def _build_subscription_repository(self) -> SubscriptionRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseSubscriptionRepository,
                )

                return SupabaseSubscriptionRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemorySubscriptionRepository()
                raise
        return InMemorySubscriptionRepository()

    def _build_owner_contact_lookup(self) -> OwnerContactLookup:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_owner_contact_lookup import (  # noqa: E501
                    SupabaseOwnerContactLookup,
                )

                return SupabaseOwnerContactLookup(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryOwnerContactLookup()
                raise
        return InMemoryOwnerContactLookup()

    def _build_user_device_repository(self) -> UserDeviceRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseUserDeviceRepository,
                )

                return SupabaseUserDeviceRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryUserDeviceRepository()
                raise
        return InMemoryUserDeviceRepository()

    def _build_user_location_repository(self) -> UserLocationRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseUserLocationRepository,
                )

                return SupabaseUserLocationRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryUserLocationRepository()
                raise
        return InMemoryUserLocationRepository()

    def _build_dog_walk_repository(self) -> DogWalkRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseDogWalkRepository,
                )

                return SupabaseDogWalkRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryDogWalkRepository()
                raise
        return InMemoryDogWalkRepository()

    def _build_weight_measurement_repository(self) -> WeightMeasurementRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseWeightMeasurementRepository,
                )

                return SupabaseWeightMeasurementRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryWeightMeasurementRepository()
                raise
        return InMemoryWeightMeasurementRepository()

    def _build_chat_response_report_repository(self) -> ChatResponseReportRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseChatResponseReportRepository,
                )

                return SupabaseChatResponseReportRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryChatResponseReportRepository()
                raise
        return InMemoryChatResponseReportRepository()

    def _build_chat_attachment_repository(self) -> ChatAttachmentRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseChatAttachmentRepository,
                )

                return SupabaseChatAttachmentRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryChatAttachmentRepository()
                raise
        return InMemoryChatAttachmentRepository()

    def _build_media_storage(self) -> MediaStorage:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.storage.supabase_media_storage import (
                    SupabaseMediaStorage,
                )

                return SupabaseMediaStorage(
                    build_supabase_client(self.settings), self.settings.media_storage_bucket
                )
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return LocalFileStorage(self.settings)
                raise
        return LocalFileStorage(self.settings)

    def _build_local_activity_repository(self) -> LocalActivityRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseLocalActivityRepository,
                )

                return SupabaseLocalActivityRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryLocalActivityRepository()
                raise
        return InMemoryLocalActivityRepository()
