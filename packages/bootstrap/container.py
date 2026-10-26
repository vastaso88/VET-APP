import hashlib
import hmac
import logging
from datetime import timedelta
from functools import lru_cache

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.account_eraser import AccountEraser
from packages.core.application.ports.answer_cache_repository import AnswerCacheRepository
from packages.core.application.ports.auth_provider import AuthProvider
from packages.core.application.ports.chat_attachment_repository import ChatAttachmentRepository
from packages.core.application.ports.chat_response_report_repository import (
    ChatResponseReportRepository,
)
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.dog_walk_repository import DogWalkRepository
from packages.core.application.ports.event_submission_repository import (
    EventSubmissionRepository,
)
from packages.core.application.ports.evidence_retriever import EvidenceRetriever
from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.core.application.ports.listing_report_repository import ListingReportRepository
from packages.core.application.ports.llm_client import LLMClient
from packages.core.application.ports.llm_usage_repository import LlmUsageRepository
from packages.core.application.ports.local_activity_repository import LocalActivityRepository
from packages.core.application.ports.marketplace_listing_repository import (
    MarketplaceListingRepository,
)
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.ports.pet_condition_repository import PetConditionRepository
from packages.core.application.ports.pet_news import PetNewsCacheRepository
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.pii_anonymizer import PiiAnonymizer
from packages.core.application.ports.radar_catalog_repository import RadarCatalogRepository
from packages.core.application.ports.radar_places_repository import RadarPlacesRepository
from packages.core.application.ports.radar_places_source import RadarPlacesSource
from packages.core.application.ports.radar_reports_repository import RadarReportsRepository
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider
from packages.core.application.ports.subscription_repository import SubscriptionRepository
from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.application.ports.weight_measurement_repository import (
    WeightMeasurementRepository,
)
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.consent_interpreter import ConsentInterpreter
from packages.core.application.services.create_listing import CreateListingService
from packages.core.application.services.create_local_activity import CreateLocalActivityService
from packages.core.application.services.create_pet_profile import CreatePetProfileService
from packages.core.application.services.create_reminder import CreateReminderService
from packages.core.application.services.delete_account import DeleteAccountService
from packages.core.application.services.delete_conversation import DeleteConversationService
from packages.core.application.services.document_summarizer import DocumentSummarizer
from packages.core.application.services.edit_chat_message import EditChatMessageService
from packages.core.application.services.end_walk import EndWalkService
from packages.core.application.services.evidence_query_normalizer import (
    EvidenceQueryNormalizer,
)
from packages.core.application.services.geocoding import GeocodingService
from packages.core.application.services.get_account_consents import GetAccountConsentsService
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.get_pet_news import GetPetNewsService
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
from packages.core.application.services.list_nearby_radar_places import (
    ListNearbyRadarPlacesService,
)
from packages.core.application.services.list_pet_profiles import ListPetProfilesService
from packages.core.application.services.list_reminders import ListRemindersService
from packages.core.application.services.list_walks import ListWalksService
from packages.core.application.services.llm_budget import LlmBudget, parse_budgets
from packages.core.application.services.llm_usage_recorder import InstrumentedLLMClient
from packages.core.application.services.maintain_chat_response_reports import (
    ChatResponseReportMaintenanceService,
)
from packages.core.application.services.maintain_chat_usage import (
    ChatUsageMaintenanceService,
)
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.radar_reports import (
    RadarCommunityView,
    RadarReportSettings,
    RateDogParkService,
    SubmitRadarReportService,
    VoteRadarReportService,
    WithdrawRadarReportService,
)
from packages.core.application.services.record_route_point import RecordRoutePointService
from packages.core.application.services.reminder_context_retriever import (
    ReminderContextRetriever,
)
from packages.core.application.services.rename_conversation import (
    RenameConversationService,
)
from packages.core.application.services.report_chat_response import ReportChatResponseService
from packages.core.application.services.report_listing import ReportListingService
from packages.core.application.services.request_radar_places_ingestion import (
    RequestRadarPlacesIngestionService,
)
from packages.core.application.services.resolve_chat_response_report import (
    ResolveChatResponseReportService,
)
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.application.services.select_plan import SelectPlanService
from packages.core.application.services.send_chat_message import SendChatMessageService
from packages.core.application.services.set_account_consent import SetAccountConsentService
from packages.core.application.services.set_medical_record_consent import (
    SetMedicalRecordConsentService,
)
from packages.core.application.services.set_user_location import SetUserLocationService
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.application.services.start_walk import StartWalkService
from packages.core.application.services.submit_event import SubmitEventService
from packages.core.application.services.transcribe_audio import TranscribeAudioService
from packages.core.application.services.update_listing import UpdateListingService
from packages.core.application.services.update_pet_profile import UpdatePetProfileService
from packages.core.application.services.upload_chat_attachment import UploadChatAttachmentService
from packages.core.application.services.urgency_classifier import UrgencyClassifier
from packages.core.application.services.vet_summary import VetSummaryService
from packages.infrastructure.auth.bootstrap_auth_provider import BootstrapAuthProvider
from packages.infrastructure.documents.pypdf_reader import PypdfReader
from packages.infrastructure.geocoding.nominatim_geocoder import NominatimGeocoder
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.providers.groq_chat_api import split_models
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
from packages.infrastructure.news.feed_reader import HttpPetNewsFeedReader
from packages.infrastructure.persistence.in_memory_account_eraser import InMemoryAccountEraser
from packages.infrastructure.persistence.in_memory_event_submissions import (
    InMemoryEventSubmissionRepository,
)
from packages.infrastructure.persistence.in_memory_pet_news import (
    InMemoryPetNewsCacheRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAccountConsentsRepository,
    InMemoryAnswerCacheRepository,
    InMemoryChatAttachmentRepository,
    InMemoryChatResponseReportRepository,
    InMemoryClinicalEventRepository,
    InMemoryConversationRepository,
    InMemoryDogWalkRepository,
    InMemoryListingReportRepository,
    InMemoryLlmUsageRepository,
    InMemoryLocalActivityRepository,
    InMemoryMarketplaceListingRepository,
    InMemoryPetConditionRepository,
    InMemoryPetProfileRepository,
    InMemoryRadarCatalogRepository,
    InMemoryRadarPlacesRepository,
    InMemoryRadarReportsRepository,
    InMemoryReminderRepository,
    InMemorySubscriptionRepository,
    InMemoryUserLocationRepository,
    InMemoryWeightMeasurementRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer
from packages.infrastructure.radar_places.overpass_places_source import (
    OverpassRadarPlacesSource,
)
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

logger = logging.getLogger(__name__)


class ApplicationContainer:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._pet_news_service: GetPetNewsService | None = None
        self._event_submission_repository: EventSubmissionRepository | None = None
        self.auth_provider = self._build_auth_provider()
        (
            self.pet_profile_repository,
            self.conversation_repository,
            self.reminder_repository,
        ) = self._build_repositories()
        # The usage ledger and the daily budget come before the model client:
        # the client reports every call to them and asks the budget which
        # model may answer (build 32, free-tier economy).
        self.llm_usage_repository = self._build_llm_usage_repository()
        self.answer_cache_repository = self._build_answer_cache_repository()
        self.llm_budget = LlmBudget(
            self.llm_usage_repository,
            budgets=parse_budgets(settings.llm_daily_token_budgets),
            default_budget=settings.llm_default_daily_token_budget,
            reserve_share=settings.llm_budget_reserve_share,
            user_daily_limit=settings.chat_daily_message_limit_per_user,
        )
        self.llm_client: LLMClient = InstrumentedLLMClient(
            self._build_llm_client(),
            repository=self.llm_usage_repository,
            budget=self.llm_budget,
        )
        self.speech_to_text_provider = self._build_speech_to_text_provider()
        self.evidence_retriever = self._build_evidence_retriever()
        self.pii_anonymizer = self._build_pii_anonymizer()
        self.clinical_event_repository = self._build_clinical_event_repository()
        self.pet_condition_repository = self._build_pet_condition_repository()
        self.account_consents_repository = self._build_account_consents_repository()
        self.subscription_repository = self._build_subscription_repository()
        self.developer_emails = frozenset(
            email.strip().lower() for email in settings.developer_emails
        )
        self.user_location_repository = self._build_user_location_repository()
        self.dog_walk_repository = self._build_dog_walk_repository()
        self.weight_measurement_repository = self._build_weight_measurement_repository()
        self.radar_places_repository = self._build_radar_places_repository()
        self.radar_catalog_repository = self._build_radar_catalog_repository()
        self.radar_reports_repository = self._build_radar_reports_repository()
        self.radar_places_source: RadarPlacesSource = OverpassRadarPlacesSource(settings)
        # One per process: it holds the per-account request counts.
        self.geocoding_service = GeocodingService(NominatimGeocoder(settings))
        self.marketplace_listing_repository = self._build_marketplace_listing_repository()
        self.listing_report_repository = self._build_listing_report_repository()
        self.local_activity_repository = self._build_local_activity_repository()
        self.chat_response_report_repository = self._build_chat_response_report_repository()
        self.chat_attachment_repository = self._build_chat_attachment_repository()
        self.media_storage: MediaStorage = self._build_media_storage()
        self.image_analyzer = self._build_image_analyzer()
        self.chat_orchestrator = ChatOrchestrator(
            self.llm_client,
            self.evidence_retriever,
            self.pii_anonymizer,
            safety_gate=SafetyGate(),
            situation_model_builder=SituationModelBuilder(self.llm_client),
            interview_planner=InterviewPlanner(self.llm_client),
            medical_record_context_retriever=MedicalRecordContextRetriever(
                self.clinical_event_repository,
                attachment_repository=self.chat_attachment_repository,
                condition_repository=self.pet_condition_repository,
            ),
            consent_interpreter=ConsentInterpreter(self.llm_client),
            enable_interview_loop=settings.enable_interview_loop,
            coverage_target=settings.situation_coverage_target,
            max_interview_questions=settings.interview_max_questions,
            response_language=settings.response_language,
            usage_budget=self.llm_budget,
            answer_models=[settings.llm_model, *split_models(settings.llm_fallback_models)],
            urgency_classifier=(
                UrgencyClassifier(
                    self.llm_client,
                    timeout_seconds=settings.urgency_classifier_timeout_seconds,
                )
                if settings.urgency_classifier_enabled
                else None
            ),
            evidence_query_normalizer=(
                EvidenceQueryNormalizer(self.llm_client)
                if settings.evidence_query_normalizer_enabled
                else None
            ),
            answer_cache=(
                self.answer_cache_repository if settings.chat_answer_cache_enabled else None
            ),
            answer_cache_ttl_hours=settings.chat_answer_cache_ttl_hours,
            answer_max_tokens=settings.llm_answer_max_tokens,
            prompt_max_sources=settings.llm_prompt_max_sources,
            prompt_source_chars=settings.llm_prompt_source_chars,
            history_recent_messages=settings.llm_history_recent_messages,
            history_message_chars=settings.llm_history_message_chars,
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

    def get_or_create_subscription_service(self) -> GetOrCreateSubscriptionService:
        return GetOrCreateSubscriptionService(self.subscription_repository, self.developer_emails)

    def delete_account_service(self) -> DeleteAccountService:
        return DeleteAccountService(self._build_account_eraser())

    def _build_account_eraser(self) -> AccountEraser:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_eraser import (
                    SupabaseAccountEraser,
                )

                radar = self.radar_report_settings()
                return SupabaseAccountEraser(
                    build_supabase_client(self.settings),
                    media_bucket=self.settings.media_storage_bucket,
                    chat_reporter_secret=self.settings.reporter_pseudonym_secret(),
                    radar_pseudonym_key=radar.pseudonym_key if radar else None,
                )
            except ModuleNotFoundError:
                if self.settings.environment == "production":
                    raise
        return InMemoryAccountEraser()

    def select_plan_service(self) -> SelectPlanService:
        return SelectPlanService(self.subscription_repository)

    def submit_event_service(self) -> SubmitEventService:
        return SubmitEventService(self.event_submission_repository())

    def event_submission_repository(self) -> EventSubmissionRepository:
        """One per process (the in-memory double must keep its queue)."""
        if self._event_submission_repository is None:
            self._event_submission_repository = self._build_event_submission_repository()
        return self._event_submission_repository

    def _build_event_submission_repository(self) -> EventSubmissionRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase import (
                    supabase_event_submissions,
                )
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )

                return supabase_event_submissions.SupabaseEventSubmissionRepository(
                    build_supabase_client(self.settings)
                )
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryEventSubmissionRepository()
                raise
        return InMemoryEventSubmissionRepository()

    def pet_news_service(self) -> GetPetNewsService:
        """One per process: it remembers when the feeds last failed."""
        if self._pet_news_service is None:
            self._pet_news_service = GetPetNewsService(
                self._build_pet_news_cache(),
                HttpPetNewsFeedReader(
                    disabled_feed_keys=frozenset(
                        key.strip()
                        for key in self.settings.news_disabled_feeds.split(",")
                        if key.strip()
                    )
                ),
                ttl=timedelta(minutes=self.settings.news_cache_ttl_minutes),
            )
        return self._pet_news_service

    def _build_pet_news_cache(self) -> PetNewsCacheRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_pet_news import (
                    SupabasePetNewsCacheRepository,
                )

                return SupabasePetNewsCacheRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryPetNewsCacheRepository()
                raise
        return InMemoryPetNewsCacheRepository()

    def list_nearby_radar_places_service(self) -> ListNearbyRadarPlacesService:
        return ListNearbyRadarPlacesService(
            self.radar_places_repository,
            RequestRadarPlacesIngestionService(
                self.radar_places_repository, self.radar_places_source
            ),
            self.radar_catalog_repository,
            self.radar_community_view(),
            max_search_radius_km=self.settings.radar_search_radius_km,
            freshness_ttl_hours=self.settings.radar_freshness_ttl_hours,
            open_sources=self.radar_open_sources(),
        )

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

    def update_listing_service(self) -> UpdateListingService:
        return UpdateListingService(self.marketplace_listing_repository)

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
            reminder_context_retriever=ReminderContextRetriever(self.reminder_repository),
            weight_measurement_repository=self.weight_measurement_repository,
            max_active_conversations_per_pet=self.settings.max_active_conversations_per_pet,
            quota_exempt_emails=self.developer_emails,
        )

    def chat_usage_maintenance_service(self) -> ChatUsageMaintenanceService:
        return ChatUsageMaintenanceService(self.llm_usage_repository, self.answer_cache_repository)

    def list_conversations_service(self) -> ListConversationsService:
        return ListConversationsService(self.conversation_repository)

    def delete_conversation_service(self) -> DeleteConversationService:
        return DeleteConversationService(self.conversation_repository)

    def edit_chat_message_service(self) -> EditChatMessageService:
        return EditChatMessageService(
            self.conversation_repository, self.send_chat_message_service()
        )

    def rename_conversation_service(self) -> RenameConversationService:
        return RenameConversationService(self.conversation_repository)

    def vet_summary_service(self) -> VetSummaryService:
        return VetSummaryService(
            self.conversation_repository,
            self.pet_profile_repository,
            self.llm_client,
            self.pii_anonymizer,
        )

    def create_reminder_service(self) -> CreateReminderService:
        return CreateReminderService(self.reminder_repository, self.pet_profile_repository)

    def list_reminders_service(self) -> ListRemindersService:
        return ListRemindersService(self.reminder_repository)

    def report_chat_response_service(self) -> ReportChatResponseService:
        return ReportChatResponseService(
            self.conversation_repository,
            self.chat_response_report_repository,
            self.pii_anonymizer,
            self.settings.reporter_pseudonym_secret(),
        )

    def chat_response_report_maintenance_service(self) -> ChatResponseReportMaintenanceService:
        return ChatResponseReportMaintenanceService(
            self.chat_response_report_repository, self.settings.reporter_pseudonym_secret()
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
            pdf_reader=PypdfReader(),
            document_summarizer=DocumentSummarizer(self.llm_client, self.pii_anonymizer),
            pii_anonymizer=self.pii_anonymizer,
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
            return GroqLLMClient(self.settings, availability=self.llm_budget)
        return EchoLLMClient(self.settings)

    def _build_llm_usage_repository(self) -> LlmUsageRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseLlmUsageRepository,
                )

                return SupabaseLlmUsageRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryLlmUsageRepository()
                raise
        return InMemoryLlmUsageRepository()

    def _build_answer_cache_repository(self) -> AnswerCacheRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseAnswerCacheRepository,
                )

                return SupabaseAnswerCacheRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryAnswerCacheRepository()
                raise
        return InMemoryAnswerCacheRepository()

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
                # Presidio isn't installed here (it is too heavy for the
                # serverless runtime): fall back to the rules, never to
                # "nothing removed".
                logger.warning("presidio not installed: using the rule-based PII anonymizer")
                return RuleBasedPiiAnonymizer()
        if (
            self.settings.pii_anonymizer_backend == "noop"
            and self.settings.environment != "production"
        ):
            return NoopPiiAnonymizer()
        # The default — and what production gets even if "noop" is set.
        return RuleBasedPiiAnonymizer()

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

    def radar_report_settings(self) -> RadarReportSettings | None:
        """None when contributions are switched off: in production with no
        secret to key pseudonyms with, rather than using a known key."""
        key = self.settings.radar_pseudonym_key.strip()
        service_key = self.settings.supabase_service_role_key.strip()
        if not key and service_key:
            # Domain-separated derivation: a secret the deployment already
            # has, bound to this one purpose by the label, so it is not the
            # service key itself and is not shared with any other feature.
            # Never logged. Rotating the service key changes it.
            key = hmac.new(
                service_key.encode("utf-8"), b"radar-contributions-v1", hashlib.sha256
            ).hexdigest()
        if not key:
            if self.settings.environment == "production":
                return None
            key = "local-development-only"
        return RadarReportSettings(
            pseudonym_key=key,
            confirmations_required=self.settings.radar_report_confirmations,
            closed_confirmations_required=self.settings.radar_report_closed_confirmations,
            daily_limit=self.settings.radar_report_daily_limit,
            expiry_days=self.settings.radar_report_expiry_days,
            missing_place_types=frozenset(self.settings.radar_report_place_types),
            show_pending_closures=self.settings.radar_report_show_pending_closures,
            reports_enabled=self.settings.radar_reports_enabled,
            closed_reports_enabled=self.settings.radar_report_closed_enabled,
            ratings_enabled=self.settings.radar_ratings_enabled,
        )

    def radar_open_sources(self) -> frozenset[str] | None:
        """Sources of `radar_places_open` that are served; None is all."""
        names = {name.strip() for name in self.settings.radar_open_sources}
        return None if "*" in names else frozenset(names)

    def radar_community_view(self) -> RadarCommunityView | None:
        settings = self.radar_report_settings()
        if settings is None:
            return None
        return RadarCommunityView(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def submit_radar_report_service(self) -> SubmitRadarReportService | None:
        settings = self.radar_report_settings()
        if settings is None or not settings.reports_enabled:
            return None
        return SubmitRadarReportService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def withdraw_radar_report_service(self) -> WithdrawRadarReportService | None:
        # Also with reports switched off: taking back one's own is always allowed.
        settings = self.radar_report_settings()
        if settings is None:
            return None
        return WithdrawRadarReportService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def vote_radar_report_service(self) -> VoteRadarReportService | None:
        settings = self.radar_report_settings()
        if settings is None or not settings.reports_enabled:
            return None
        return VoteRadarReportService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def rate_dog_park_service(self) -> RateDogParkService | None:
        settings = self.radar_report_settings()
        if settings is None or not settings.ratings_enabled:
            return None
        return RateDogParkService(
            self.radar_reports_repository, self.account_consents_repository, settings
        )

    def _build_radar_reports_repository(self) -> RadarReportsRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseRadarReportsRepository,
                )

                return SupabaseRadarReportsRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryRadarReportsRepository()
                raise
        return InMemoryRadarReportsRepository()

    def _build_radar_catalog_repository(self) -> RadarCatalogRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseRadarCatalogRepository,
                )

                return SupabaseRadarCatalogRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryRadarCatalogRepository()
                raise
        return InMemoryRadarCatalogRepository()

    def _build_radar_places_repository(self) -> RadarPlacesRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_repositories import (
                    SupabaseRadarPlacesRepository,
                )

                return SupabaseRadarPlacesRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryRadarPlacesRepository()
                raise
        return InMemoryRadarPlacesRepository()

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
