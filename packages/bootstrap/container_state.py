"""What the wiring mixins may assume about the container they are mixed into.

`ApplicationContainer` is assembled from small mixin classes (one per group of services:
radar, events and news, marketplace, account lifecycle, platform builders). A mixin method
reads `self.settings` or `self.some_repository` and calls `self.some_other_factory()`. At run
time all of that exists on the final container object; this class only tells the type checker
the same thing. It holds annotations and, under TYPE_CHECKING, method signatures: nothing here
creates an attribute or a method at run time, so the container keeps exactly the same names,
the same state and the same initialisation order as before the split.
"""

from datetime import datetime
from typing import TYPE_CHECKING

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.account_deletion_repository import AccountDeletionRepository
from packages.core.application.ports.account_pause_repository import AccountPauseRepository
from packages.core.application.ports.answer_cache_repository import AnswerCacheRepository
from packages.core.application.ports.auth_provider import AuthProvider
from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.email_sender import EmailSender
from packages.core.application.ports.event_catalog_repository import EventCatalogRepository
from packages.core.application.ports.event_submission_repository import EventSubmissionRepository
from packages.core.application.ports.evidence_retriever import EvidenceRetriever
from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.core.application.ports.listing_report_repository import ListingReportRepository
from packages.core.application.ports.llm_client import LLMClient
from packages.core.application.ports.llm_usage_repository import LlmUsageRepository
from packages.core.application.ports.local_activity_repository import LocalActivityRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.ports.marketplace_messaging_repository import (
    MarketplaceMessagingRepository,
)
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.ports.message_key_repository import MessageKeyRepository
from packages.core.application.ports.owner_contact_lookup import OwnerContactLookup
from packages.core.application.ports.pet_condition_repository import PetConditionRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.pii_anonymizer import PiiAnonymizer
from packages.core.application.ports.radar_catalog_repository import RadarCatalogRepository
from packages.core.application.ports.radar_places_repository import RadarPlacesRepository
from packages.core.application.ports.radar_places_source import RadarPlacesSource
from packages.core.application.ports.radar_reports_repository import RadarReportsRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider
from packages.core.application.ports.store_billing import StoreEntitlementRepository
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.application.ports.user_device_repository import UserDeviceRepository
from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.application.ports.weight_measurement_repository import (
    WeightMeasurementRepository,
)
from packages.core.application.services.account_pause import AccountPauseService
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.application.services.geocoding import GeocodingService
from packages.core.application.services.get_pet_news import GetPetNewsService
from packages.core.application.services.llm_budget import LlmBudget
from packages.core.application.services.plan_access_sync import PlanAccessSync
from packages.core.application.services.radar_reports import RadarReportSettings
from packages.core.application.services.store_billing import StoreBillingService
from packages.core.domain.subscription.limits import PlanLimits
from packages.shared.config.settings import Settings


class ContainerState:
    # Attributes the container sets in __init__ (annotations only: no run-time effect).
    settings: Settings
    auth_provider: AuthProvider
    pet_profile_repository: PetProfileRepository
    conversation_repository: ConversationRepository
    reminder_repository: ReminderRepository
    llm_usage_repository: LlmUsageRepository
    answer_cache_repository: AnswerCacheRepository
    llm_budget: LlmBudget
    llm_client: LLMClient
    speech_to_text_provider: SpeechToTextProvider
    evidence_retriever: EvidenceRetriever
    pii_anonymizer: PiiAnonymizer
    clinical_event_repository: ClinicalEventRepository
    pet_condition_repository: PetConditionRepository
    account_consents_repository: AccountConsentsRepository
    subscription_repository: SubscriptionRepository
    user_device_repository: UserDeviceRepository
    account_age_repository: AccountAgeRepository
    account_deletion_repository: AccountDeletionRepository
    deletion_log_service: DeletionLogService
    account_pause_repository: AccountPauseRepository
    email_sender: EmailSender
    owner_contact_lookup: OwnerContactLookup
    developer_emails: frozenset[str]
    subscription_test_plan: str | None
    memorial_pets_max: int
    plan_access_sync: PlanAccessSync | None
    store_entitlement_repository: StoreEntitlementRepository
    _store_billing: StoreBillingService | None
    last_verified_access: dict[str, tuple[datetime, bool, PlanLimits | None]]
    user_location_repository: UserLocationRepository
    dog_walk_repository: DogWalkRepository
    weight_measurement_repository: WeightMeasurementRepository
    radar_places_repository: RadarPlacesRepository
    radar_catalog_repository: RadarCatalogRepository
    radar_reports_repository: RadarReportsRepository
    radar_places_source: RadarPlacesSource
    geocoding_service: GeocodingService
    marketplace_listing_repository: MarketplaceListingRepository
    listing_report_repository: ListingReportRepository
    marketplace_messaging_repository: MarketplaceMessagingRepository
    local_activity_repository: LocalActivityRepository
    chat_response_report_repository: ChatResponseReportRepository
    chat_attachment_repository: ChatAttachmentRepository
    chat_message_key_repository: MessageKeyRepository
    media_storage: MediaStorage
    image_analyzer: ImageAnalyzer
    chat_orchestrator: ChatOrchestrator
    _pet_news_service: GetPetNewsService | None
    _event_submission_repository: EventSubmissionRepository | None
    _event_catalog_repository: EventCatalogRepository | None

    if TYPE_CHECKING:
        # Signatures of factories that one group calls on another.
        def hidden_owner_ids(self) -> set[str]: ...

        def radar_report_settings(self) -> RadarReportSettings | None: ...

        def account_pause_service(self) -> AccountPauseService: ...
