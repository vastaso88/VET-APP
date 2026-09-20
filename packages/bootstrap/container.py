from functools import lru_cache

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.auth_provider import AuthProvider
from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.evidence_retriever import EvidenceRetriever
from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.core.application.ports.listing_report_repository import ListingReportRepository
from packages.core.application.ports.local_activity_repository import LocalActivityRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.pii_anonymizer import PiiAnonymizer
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider
from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.consent_interpreter import ConsentInterpreter
from packages.core.application.services.create_listing import CreateListingService
from packages.core.application.services.create_local_activity import CreateLocalActivityService
from packages.core.application.services.create_pet_profile import CreatePetProfileService
from packages.core.application.services.create_reminder import CreateReminderService
from packages.core.application.services.delete_conversation import DeleteConversationService
from packages.core.application.services.end_walk import EndWalkService
from packages.core.application.services.get_account_consents import GetAccountConsentsService
from packages.core.application.services.get_pet_profile import GetPetProfileService
from packages.core.application.services.get_user_location import GetUserLocationService
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.application.services.list_chat_response_reports import (
    ListChatResponseReportsService,
)
from packages.core.application.services.list_conversations import ListConversationsService
from packages.core.application.services.list_nearby_activities import (
    ListNearbyActivitiesService,
)
from packages.core.application.services.list_nearby_listings import ListNearbyListingsService
from packages.core.application.services.list_pet_profiles import ListPetProfilesService
from packages.core.application.services.list_reminders import ListRemindersService
from packages.core.application.services.list_walks import ListWalksService
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.record_route_point import RecordRoutePointService
from packages.core.application.services.report_chat_response import ReportChatResponseService
from packages.core.application.services.report_listing import ReportListingService
from packages.core.application.services.resolve_chat_response_report import (
    ResolveChatResponseReportService,
)
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.application.services.send_chat_message import SendChatMessageService
from packages.core.application.services.set_account_consent import SetAccountConsentService
from packages.core.application.services.set_medical_record_consent import (
    SetMedicalRecordConsentService,
)
from packages.core.application.services.set_user_location import SetUserLocationService
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.application.services.start_walk import StartWalkService
from packages.core.application.services.transcribe_audio import TranscribeAudioService
from packages.core.application.services.update_pet_profile import UpdatePetProfileService
from packages.core.application.services.upload_chat_attachment import UploadChatAttachmentService
from packages.infrastructure.auth.bootstrap_auth_provider import BootstrapAuthProvider
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.providers.groq_llm_client import GroqLLMClient
from packages.infrastructure.llm.retrieval.crossref_evidence_retriever import (
    CrossrefEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.curated_husbandry_evidence_retriever import (
    CuratedHusbandryEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.europe_pmc_evidence_retriever import (
    EuropePmcEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.intent_routed_evidence_retriever import (
    IntentRoutedEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.multi_source_evidence_retriever import (
    MultiSourceEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.openalex_evidence_retriever import (
    OpenAlexEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.pubmed_evidence_retriever import (
    PubMedEvidenceRetriever,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
    InMemoryChatAttachmentRepository,
    InMemoryChatResponseReportRepository,
    InMemoryClinicalEventRepository,
    InMemoryConversationRepository,
    InMemoryDogWalkRepository,
    InMemoryListingReportRepository,
    InMemoryLocalActivityRepository,
    InMemoryMarketplaceListingRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
    InMemoryUserLocationRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.infrastructure.speech.echo_speech_to_text_provider import (
    EchoSpeechToTextProvider,
)
from packages.infrastructure.speech.groq_speech_to_text_provider import (
    GroqSpeechToTextProvider,
)
from packages.infrastructure.storage.local_file_storage import LocalFileStorage
from packages.infrastructure.vision.echo_image_analyzer import EchoImageAnalyzer
from packages.infrastructure.vision.groq_image_analyzer import GroqImageAnalyzer
from packages.shared.config.settings import Settings, get_settings


class ApplicationContainer:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.auth_provider = self._build_auth_provider()
        (
            self.pet_profile_repository,
            self.conversation_repository,
            self.reminder_repository,
        ) = self._build_repositories()
        self.llm_client = self._build_llm_client()
        self.speech_to_text_provider = self._build_speech_to_text_provider()
        self.evidence_retriever = self._build_evidence_retriever()
        self.pii_anonymizer = self._build_pii_anonymizer()
        self.clinical_event_repository = self._build_clinical_event_repository()
        self.account_consents_repository = self._build_account_consents_repository()
        self.user_location_repository = self._build_user_location_repository()
        self.dog_walk_repository = self._build_dog_walk_repository()
        self.marketplace_listing_repository = self._build_marketplace_listing_repository()
        self.listing_report_repository = self._build_listing_report_repository()
        self.local_activity_repository = self._build_local_activity_repository()
        self.chat_response_report_repository = self._build_chat_response_report_repository()
        self.chat_attachment_repository = self._build_chat_attachment_repository()
        self.media_storage: MediaStorage = LocalFileStorage(settings)
        self.image_analyzer = self._build_image_analyzer()
        self.chat_orchestrator = ChatOrchestrator(
            self.llm_client,
            self.evidence_retriever,
            self.pii_anonymizer,
            safety_gate=SafetyGate(),
            situation_model_builder=SituationModelBuilder(self.llm_client),
            interview_planner=InterviewPlanner(),
            medical_record_context_retriever=MedicalRecordContextRetriever(
                self.clinical_event_repository
            ),
            consent_interpreter=ConsentInterpreter(),
            enable_interview_loop=settings.enable_interview_loop,
            coverage_target=settings.situation_coverage_target,
            max_interview_questions=settings.interview_max_questions,
            response_language=settings.response_language,
        )

    def create_pet_profile_service(self) -> CreatePetProfileService:
        return CreatePetProfileService(self.pet_profile_repository)

    def get_pet_profile_service(self) -> GetPetProfileService:
        return GetPetProfileService(self.pet_profile_repository)

    def update_pet_profile_service(self) -> UpdatePetProfileService:
        return UpdatePetProfileService(self.pet_profile_repository)

    def list_pet_profiles_service(self) -> ListPetProfilesService:
        return ListPetProfilesService(self.pet_profile_repository)

    def set_medical_record_consent_service(self) -> SetMedicalRecordConsentService:
        return SetMedicalRecordConsentService(self.pet_profile_repository)

    def get_account_consents_service(self) -> GetAccountConsentsService:
        return GetAccountConsentsService(self.account_consents_repository)

    def set_account_consent_service(self) -> SetAccountConsentService:
        return SetAccountConsentService(self.account_consents_repository)

    def get_user_location_service(self) -> GetUserLocationService:
        return GetUserLocationService(self.user_location_repository)

    def set_user_location_service(self) -> SetUserLocationService:
        return SetUserLocationService(self.user_location_repository)

    def start_walk_service(self) -> StartWalkService:
        return StartWalkService(self.dog_walk_repository, self.pet_profile_repository)

    def record_route_point_service(self) -> RecordRoutePointService:
        return RecordRoutePointService(self.dog_walk_repository)

    def end_walk_service(self) -> EndWalkService:
        return EndWalkService(self.dog_walk_repository)

    def list_walks_service(self) -> ListWalksService:
        return ListWalksService(self.dog_walk_repository)

    def create_listing_service(self) -> CreateListingService:
        return CreateListingService(self.marketplace_listing_repository)

    def list_nearby_listings_service(self) -> ListNearbyListingsService:
        return ListNearbyListingsService(self.marketplace_listing_repository)

    def report_listing_service(self) -> ReportListingService:
        return ReportListingService(
            self.marketplace_listing_repository, self.listing_report_repository
        )

    def create_local_activity_service(self) -> CreateLocalActivityService:
        return CreateLocalActivityService(self.local_activity_repository)

    def list_nearby_activities_service(self) -> ListNearbyActivitiesService:
        return ListNearbyActivitiesService(self.local_activity_repository)

    def send_chat_message_service(self) -> SendChatMessageService:
        return SendChatMessageService(
            self.conversation_repository,
            self.chat_orchestrator,
            self.pet_profile_repository,
            attachment_repository=self.chat_attachment_repository,
            max_active_conversations_per_pet=self.settings.max_active_conversations_per_pet,
        )

    def list_conversations_service(self) -> ListConversationsService:
        return ListConversationsService(self.conversation_repository)

    def delete_conversation_service(self) -> DeleteConversationService:
        return DeleteConversationService(self.conversation_repository)

    def create_reminder_service(self) -> CreateReminderService:
        return CreateReminderService(self.reminder_repository, self.pet_profile_repository)

    def list_reminders_service(self) -> ListRemindersService:
        return ListRemindersService(self.reminder_repository)

    def report_chat_response_service(self) -> ReportChatResponseService:
        return ReportChatResponseService(
            self.conversation_repository, self.chat_response_report_repository
        )

    def list_chat_response_reports_service(self) -> ListChatResponseReportsService:
        return ListChatResponseReportsService(self.chat_response_report_repository)

    def resolve_chat_response_report_service(self) -> ResolveChatResponseReportService:
        return ResolveChatResponseReportService(self.chat_response_report_repository)

    def transcribe_audio_service(self) -> TranscribeAudioService:
        return TranscribeAudioService(self.speech_to_text_provider)

    def upload_chat_attachment_service(self) -> UploadChatAttachmentService:
        return UploadChatAttachmentService(
            self.pet_profile_repository,
            self.chat_attachment_repository,
            self.media_storage,
            self.image_analyzer,
        )

    def _build_auth_provider(self) -> AuthProvider:
        if self.settings.auth_backend == "supabase":
            try:
                from packages.infrastructure.auth.supabase_auth_provider import (
                    SupabaseAuthProvider,
                )
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                    build_supabase_public_client,
                )

                return SupabaseAuthProvider(
                    public_client=build_supabase_public_client(self.settings),
                    admin_client=build_supabase_client(self.settings),
                )
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return BootstrapAuthProvider(self.settings)
                raise
        return BootstrapAuthProvider(self.settings)

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

    def _build_llm_client(self) -> EchoLLMClient | GroqLLMClient:
        if self.settings.llm_provider == "groq":
            return GroqLLMClient(self.settings)
        return EchoLLMClient(self.settings)

    def _build_speech_to_text_provider(self) -> SpeechToTextProvider:
        if self.settings.stt_provider == "groq":
            return GroqSpeechToTextProvider(self.settings)
        return EchoSpeechToTextProvider()

    def _build_image_analyzer(self) -> ImageAnalyzer:
        if self.settings.vision_provider == "groq":
            return GroqImageAnalyzer(self.settings)
        return EchoImageAnalyzer()

    def _build_pii_anonymizer(self) -> PiiAnonymizer:
        if self.settings.pii_anonymizer_backend == "presidio":
            try:
                from packages.infrastructure.privacy.presidio_pii_anonymizer import (
                    PresidioPiiAnonymizer,
                )

                return PresidioPiiAnonymizer()
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return NoopPiiAnonymizer()
                raise
        return NoopPiiAnonymizer()

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

    def _build_marketplace_listing_repository(self) -> MarketplaceListingRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseMarketplaceListingRepository,
                )

                return SupabaseMarketplaceListingRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryMarketplaceListingRepository()
                raise
        return InMemoryMarketplaceListingRepository()

    def _build_listing_report_repository(self) -> ListingReportRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseListingReportRepository,
                )

                return SupabaseListingReportRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryListingReportRepository()
                raise
        return InMemoryListingReportRepository()

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

    def _build_evidence_retriever(self) -> EvidenceRetriever:
        if self.settings.evidence_backend == "europe_pmc":
            # husbandry_question is routed to the curated catalog instead
            # of Europe PMC — see IntentRoutedEvidenceRetriever's docstring
            # for the live-verified reason why pooling them doesn't work.
            return IntentRoutedEvidenceRetriever(
                default=EuropePmcEvidenceRetriever(),
                overrides={"husbandry_question": CuratedHusbandryEvidenceRetriever()},
            )
        if self.settings.evidence_backend == "scientific_multi":
            # Spec v3 §20: PubMed, Europe PMC, Crossref and OpenAlex are
            # complementary sources, not alternatives to pick one of — but
            # husbandry_question is routed to the curated catalog instead
            # of this pipeline (see IntentRoutedEvidenceRetriever).
            return IntentRoutedEvidenceRetriever(
                default=MultiSourceEvidenceRetriever(
                    [
                        EuropePmcEvidenceRetriever(),
                        PubMedEvidenceRetriever(),
                        CrossrefEvidenceRetriever(),
                        OpenAlexEvidenceRetriever(),
                    ]
                ),
                overrides={"husbandry_question": CuratedHusbandryEvidenceRetriever()},
            )
        if self.settings.evidence_backend == "supabase":
            try:
                from packages.infrastructure.llm.retrieval.supabase_evidence_retriever import (
                    SupabaseEvidenceRetriever,
                )
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )

                return SupabaseEvidenceRetriever(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryEvidenceRetriever()
                raise
        return InMemoryEvidenceRetriever()


@lru_cache(maxsize=1)
def get_container() -> ApplicationContainer:
    return ApplicationContainer(get_settings())


def reset_container() -> None:
    get_container.cache_clear()
