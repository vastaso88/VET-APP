import hashlib
import hmac
import logging
from datetime import datetime, timedelta
from functools import lru_cache
from typing import TYPE_CHECKING

from packages.core.application.ports.account_age_repository import AccountAgeRepository
from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.account_deletion_repository import (
    AccountDeletionRepository,
)
from packages.core.application.ports.account_eraser import AccountEraser
from packages.core.application.ports.account_exporter import AccountExporter
from packages.core.application.ports.account_pause_repository import (
    AccountPauseRepository,
)
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
from packages.core.application.ports.marketplace_messaging_repository import (
    MarketplaceMessagingRepository,
)
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.ports.owner_contact_lookup import OwnerContactLookup
from packages.core.application.ports.owner_limits import OwnerLimitsLookup
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
from packages.core.application.ports.user_device_repository import UserDeviceRepository
from packages.core.application.ports.user_location_repository import UserLocationRepository
from packages.core.application.ports.weight_measurement_repository import (
    WeightMeasurementRepository,
)
from packages.core.application.services.account_data_counts import AccountDataCounter
from packages.core.application.services.account_deletion import AccountDeletionService
from packages.core.application.services.account_pause import AccountPauseService
from packages.core.application.services.age_gate import AgeGateService
from packages.core.application.services.age_review_admin import AgeReviewAdminService
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.consent_interpreter import ConsentInterpreter
from packages.core.application.services.create_listing import CreateListingService
from packages.core.application.services.create_pet_profile import CreatePetProfileService
from packages.core.application.services.create_reminder import CreateReminderService
from packages.core.application.services.delete_account import DeleteAccountService
from packages.core.application.services.delete_conversation import DeleteConversationService
from packages.core.application.services.deletion_log import DeletionLogService
from packages.core.application.services.document_summarizer import DocumentSummarizer
from packages.core.application.services.edit_chat_message import EditChatMessageService
from packages.core.application.services.evidence_query_normalizer import (
    EvidenceQueryNormalizer,
)
from packages.core.application.services.export_account_data import (
    ExportAccountDataService,
)
from packages.core.application.services.geocoding import GeocodingService
from packages.core.application.services.get_account_consents import GetAccountConsentsService
from packages.core.application.services.get_or_create_subscription import (
    GetOrCreateSubscriptionInput,
    GetOrCreateSubscriptionService,
)
from packages.core.application.services.get_pet_news import GetPetNewsService
from packages.core.application.services.get_pet_profile import GetPetProfileService
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.application.services.list_chat_response_reports import (
    ListChatResponseReportsService,
)
from packages.core.application.services.list_conversations import ListConversationsService
from packages.core.application.services.list_events import ListEventsService
from packages.core.application.services.list_nearby_listings import ListNearbyListingsService
from packages.core.application.services.list_nearby_radar_places import (
    ListNearbyRadarPlacesService,
)
from packages.core.application.services.list_pet_profiles import ListPetProfilesService
from packages.core.application.services.list_reminders import ListRemindersService
from packages.core.application.services.list_travel_cards import ListTravelCardsService
from packages.core.application.services.llm_budget import LlmBudget, parse_budgets
from packages.core.application.services.llm_usage_recorder import InstrumentedLLMClient
from packages.core.application.services.llm_usage_report import LlmUsageReportService
from packages.core.application.services.maintain_chat_response_reports import (
    ChatResponseReportMaintenanceService,
)
from packages.core.application.services.maintain_chat_usage import (
    ChatRetentionService,
    ChatUsageMaintenanceService,
)
from packages.core.application.services.mark_not_helpful import MarkNotHelpfulService
from packages.core.application.services.marketplace_messaging import (
    MarketplaceMessagingModerationService,
    MarketplaceMessagingService,
)
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.plan_access_sync import PlanAccessSync
from packages.core.application.services.radar_reports import (
    RadarCommunityView,
    RadarReportSettings,
    RateDogParkService,
    SubmitCompetenceClaimService,
    SubmitRadarReportService,
    VoteRadarReportService,
    WithdrawRadarReportService,
)
from packages.core.application.services.register_device import RegisterDeviceService
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
from packages.core.application.services.retention_dry_run import RetentionDryRunService
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.application.services.select_plan import SelectPlanService
from packages.core.application.services.send_chat_message import SendChatMessageService
from packages.core.application.services.set_account_consent import SetAccountConsentService
from packages.core.application.services.set_medical_record_consent import (
    SetMedicalRecordConsentService,
)
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.application.services.submit_event import SubmitEventService
from packages.core.application.services.transcribe_audio import TranscribeAudioService
from packages.core.application.services.underage_review_dry_run import (
    UnderageReviewDryRunService,
)
from packages.core.application.services.update_listing import UpdateListingService
from packages.core.application.services.update_pet_profile import UpdatePetProfileService
from packages.core.application.services.upload_chat_attachment import UploadChatAttachmentService
from packages.core.application.services.urgency_classifier import UrgencyClassifier
from packages.core.application.services.vet_summary import VetSummaryService
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.limits import (
    DEFAULT_MAX_MEMORIAL_PETS,
    NO_ACCESS_LIMITS,
    PlanLimits,
)
from packages.core.domain.subscription.store import ProductCatalog, Store

if TYPE_CHECKING:
    from packages.infrastructure.billing.apple_app_store import AppleSignedDataDecoder
from packages.core.application.ports.store_billing import (
    StoreEntitlementRepository,
    StoreVerifier,
)
from packages.core.application.services.store_billing import StoreBillingService
from packages.core.domain.subscription.models import SubscriptionPlan
from packages.core.domain.travel.cards import load_travel_cards
from packages.infrastructure.auth.age_guarded_auth_provider import AgeGuardedAuthProvider
from packages.infrastructure.auth.bootstrap_auth_provider import BootstrapAuthProvider
from packages.infrastructure.documents.pypdf_reader import PypdfReader
from packages.infrastructure.email.in_memory_email_sender import (
    DisabledEmailSender,
    InMemoryEmailSender,
)
from packages.infrastructure.geocoding.nominatim_geocoder import NominatimGeocoder
from packages.infrastructure.llm.providers.anthropic_llm_client import AnthropicLLMClient
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.providers.groq_chat_api import split_models
from packages.infrastructure.llm.providers.groq_llm_client import GroqLLMClient
from packages.infrastructure.llm.providers.reserve_llm_client import ReserveLLMClient
from packages.infrastructure.llm.retrieval.crossref_evidence_retriever import (
    CrossrefEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.curated_awareness_evidence_retriever import (
    CuratedAwarenessEvidenceRetriever,
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
from packages.infrastructure.persistence.in_memory_account_age_repository import (
    InMemoryAccountAgeRepository,
)
from packages.infrastructure.persistence.in_memory_account_deletion_repository import (
    InMemoryAccountDeletionRepository,
)
from packages.infrastructure.persistence.in_memory_account_eraser import InMemoryAccountEraser
from packages.infrastructure.persistence.in_memory_account_exporter import (
    InMemoryAccountExporter,
)
from packages.infrastructure.persistence.in_memory_account_pause_repository import (
    InMemoryAccountPauseRepository,
)
from packages.infrastructure.persistence.in_memory_deletion_log import (
    InMemoryDeletionLogCopy,
    InMemoryDeletionLogRepository,
)
from packages.infrastructure.persistence.in_memory_event_catalog import (
    InMemoryEventCatalogRepository,
)
from packages.infrastructure.persistence.in_memory_event_submissions import (
    InMemoryEventSubmissionRepository,
)
from packages.infrastructure.persistence.in_memory_marketplace_messaging import (
    InMemoryMarketplaceMessagingRepository,
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
    InMemoryOwnerContactLookup,
    InMemoryPetConditionRepository,
    InMemoryPetProfileRepository,
    InMemoryRadarCatalogRepository,
    InMemoryRadarPlacesRepository,
    InMemoryRadarReportsRepository,
    InMemoryReminderRepository,
    InMemorySubscriptionRepository,
    InMemoryUserDeviceRepository,
    InMemoryUserLocationRepository,
    InMemoryWeightMeasurementRepository,
)
from packages.infrastructure.persistence.in_memory_store_billing import (
    InMemoryStoreEntitlementRepository,
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
from packages.infrastructure.vision.disabled_image_analyzer import DisabledImageAnalyzer
from packages.infrastructure.vision.echo_image_analyzer import EchoImageAnalyzer
from packages.infrastructure.vision.groq_image_analyzer import GroqImageAnalyzer
from packages.shared.config.groq_models import is_groq_production_model
from packages.shared.config.settings import Settings, get_settings

logger = logging.getLogger(__name__)


def _parse_plan_overrides(raw: str) -> dict[str, str]:
    """ "email:plan,email:plan" -> {email: plan}; malformed or unknown plans
    are ignored (never a crash, never a plan that does not exist)."""
    result: dict[str, str] = {}
    for item in raw.split(","):
        email, _, plan = item.strip().rpartition(":")
        plan = plan.strip().lower()
        if email.strip() and plan in SubscriptionPlan.ALL:
            result[email.strip().lower()] = plan
    return result


def _resolve_subscription_test_plan(raw: str) -> str | None:
    """SUBSCRIPTION_TEST_PLAN as a plan key, or None for the normal behaviour.
    A value that is not a plan is ignored with a warning rather than refused:
    a typo must neither take the API down at start-up (a bad variable already
    did once, 2026-10-06) nor hand out a plan nobody asked for."""
    value = raw.strip().lower()
    if not value:
        return None
    if value not in SubscriptionPlan.ALL:
        logger.warning("SUBSCRIPTION_TEST_PLAN is not a plan: ignored (normal behaviour)")
        return None
    logger.warning(
        "SUBSCRIPTION_TEST_PLAN is set: every account is on the %s plan and nobody pays",
        value,
    )
    return value


def resolve_memorial_pets_max(raw: str) -> int:
    """MEMORIAL_PETS_MAX as a whole number above zero, or the default (30). A
    value that is not one is ignored with a warning rather than refused, for the
    same reason as SUBSCRIPTION_TEST_PLAN: a typo must not take the API down at
    start-up, and "no cap" by accident (0, a negative number) is the worse
    answer for a limit that bounds how much data an account can pile up."""
    value = raw.strip()
    if not value:
        return DEFAULT_MAX_MEMORIAL_PETS
    try:
        number = int(value)
    except ValueError:
        number = 0
    if number < 1:
        logger.warning("MEMORIAL_PETS_MAX is not a whole number above zero: default used")
        return DEFAULT_MAX_MEMORIAL_PETS
    return number


def groq_reserve_configured(settings: Settings) -> bool:
    return bool(settings.llm_api_key.strip() and settings.llm_model.strip())


def answer_models(settings: Settings) -> list[str]:
    """The models an answer may come from, in order: what the budget
    checks before a turn is admitted."""
    groq = [settings.llm_model, *split_models(settings.llm_fallback_models)]
    if settings.llm_provider == "anthropic":
        return [settings.anthropic_model, *(groq if groq_reserve_configured(settings) else [])]
    return groq


class ApplicationContainer:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._pet_news_service: GetPetNewsService | None = None
        self._event_submission_repository: EventSubmissionRepository | None = None
        self._event_catalog_repository: EventCatalogRepository | None = None
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
            daily_budget_eur=settings.llm_daily_budget_eur,
            usd_per_eur=settings.llm_usd_per_eur,
            inference_geo=settings.anthropic_inference_geo,
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
        self.user_device_repository = self._build_user_device_repository()
        self.account_age_repository = self._build_account_age_repository()
        self.account_deletion_repository = self._build_account_deletion_repository()
        self.deletion_log_service = self._build_deletion_log_service()
        self.account_pause_repository = self._build_account_pause_repository()
        self.email_sender = self._build_email_sender()
        self.owner_contact_lookup = self._build_owner_contact_lookup()
        # A blank entry (a trailing comma) must not make "" a developer: an
        # unconfirmed address is compared as "" (allowlist_email).
        self.developer_emails = frozenset(
            email.strip().lower() for email in settings.developer_emails if email.strip()
        )
        self.subscription_test_plan = _resolve_subscription_test_plan(
            settings.subscription_test_plan
        )
        self.memorial_pets_max = resolve_memorial_pets_max(settings.memorial_pets_max)
        self.plan_access_sync = self._build_plan_access_sync()
        self.store_entitlement_repository = self._build_store_entitlement_repository()
        self._store_billing: StoreBillingService | None = None
        # Last verified access per owner, used only when a later check fails
        # (bounded by BILLING_VERIFICATION_TOLERANCE_HOURS, never a new right).
        self.last_verified_access: dict[str, tuple[datetime, bool, PlanLimits | None]] = {}
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
        self.marketplace_messaging_repository = self._build_marketplace_messaging_repository()
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
            answer_v2=settings.chat_answer_v2,
            urgent_lane=settings.chat_answer_v2_urgent_lane,
            person_hurt_line=settings.chat_person_hurt_line,
            coverage_target=settings.situation_coverage_target,
            max_interview_questions=settings.interview_max_questions,
            response_language=settings.response_language,
            usage_budget=self.llm_budget,
            answer_models=answer_models(settings),
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
            # Plan "fratello maggiore": OFF until the owner approves the numbers.
            strong_model=(
                settings.anthropic_model_strong
                if settings.sonnet_escalation_enabled and settings.llm_provider == "anthropic"
                else None
            ),
            answer_max_tokens=settings.llm_answer_max_tokens,
            # The demo provider echoes the prompt: its urgencies stay fixed.
            urgent_answer_timeout_seconds=(
                0 if settings.llm_provider == "echo" else settings.urgent_answer_timeout_seconds
            ),
            prompt_max_sources=settings.llm_prompt_max_sources,
            prompt_source_chars=settings.llm_prompt_source_chars,
            history_recent_messages=settings.llm_history_recent_messages,
            history_message_chars=settings.llm_history_message_chars,
        )

    def create_pet_profile_service(self) -> CreatePetProfileService:
        return CreatePetProfileService(
            self.pet_profile_repository, owner_limits=self.owner_limits_lookup()
        )

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
        return SetAccountConsentService(self.account_consents_repository, self.age_gate_service())

    def get_or_create_subscription_service(self) -> GetOrCreateSubscriptionService:
        return GetOrCreateSubscriptionService(
            self.subscription_repository,
            self.developer_emails,
            test_plan=self.subscription_test_plan,
            access_sync=self.plan_access_sync,
            max_memorial_pets=self.memorial_pets_max,
            trial_days=self.settings.billing_trial_days,
            store_billing=self.store_billing_service() if self.settings.billing_enabled else None,
            plan_overrides=_parse_plan_overrides(self.settings.billing_plan_overrides),
        )

    def _build_store_entitlement_repository(self) -> StoreEntitlementRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_store_billing import (
                    SupabaseStoreEntitlementRepository,
                )

                return SupabaseStoreEntitlementRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment == "production":
                    raise
        return InMemoryStoreEntitlementRepository()

    def store_billing_service(self) -> StoreBillingService | None:
        """None until BILLING_ACCOUNT_TOKEN_SECRET is set: without it no
        purchase can be bound to an account, so nothing is granted."""
        if self._store_billing is not None:
            return self._store_billing
        settings = self.settings
        if not settings.billing_account_token_secret:
            return None
        verifiers: dict[Store, StoreVerifier] = {}
        decoder = self.apple_signed_data_decoder()
        if decoder is not None and settings.apple_issuer_id and settings.apple_private_key:
            from packages.infrastructure.billing.apple_app_store import AppleAppStoreVerifier

            verifiers[Store.APPLE] = AppleAppStoreVerifier(
                issuer_id=settings.apple_issuer_id,
                key_id=settings.apple_key_id,
                private_key_pem=settings.apple_private_key.replace("\\n", "\n"),
                bundle_id=settings.apple_bundle_id,
                decoder=decoder,
                use_sandbox=settings.billing_store_environment == "sandbox",
            )
        if settings.google_play_package_name and settings.google_play_service_account_json:
            from packages.infrastructure.billing.google_play import GooglePlayVerifier

            verifiers[Store.GOOGLE] = GooglePlayVerifier(
                package_name=settings.google_play_package_name,
                service_account_json=settings.google_play_service_account_json,
            )
        self._store_billing = StoreBillingService(
            entitlements=self.store_entitlement_repository,
            subscriptions=self.subscription_repository,
            verifiers=verifiers,
            catalog=ProductCatalog.from_json(settings.billing_catalog_json),
            account_token_secret=settings.billing_account_token_secret,
            verification_tolerance=timedelta(hours=settings.billing_verification_tolerance_hours),
            allowed_environments=frozenset({settings.billing_store_environment}),
        )
        return self._store_billing

    def apple_signed_data_decoder(self) -> "AppleSignedDataDecoder | None":
        if not (self.settings.apple_bundle_id and self.settings.apple_root_certificates):
            return None
        from packages.infrastructure.billing.apple_app_store import (
            AppleSignedDataDecoder,
            load_root_certificates,
        )

        return AppleSignedDataDecoder(
            bundle_id=self.settings.apple_bundle_id,
            roots=load_root_certificates(self.settings.apple_root_certificates),
        )

    def _build_plan_access_sync(self) -> PlanAccessSync | None:
        """Only with the Supabase database: that is where the rules on the
        app's direct writes live (scripts/setup/plan_access_rules.sql)."""
        if self.settings.persistence_backend != "supabase":
            return None
        try:
            from packages.infrastructure.persistence.supabase.client import (
                build_supabase_client,
            )
            from packages.infrastructure.persistence.supabase.supabase_plan_access_store import (
                SupabasePlanAccessStore,
            )

            return PlanAccessSync(SupabasePlanAccessStore(build_supabase_client(self.settings)))
        except ModuleNotFoundError:
            if self.settings.environment == "production":
                raise
            return None

    def llm_usage_report_service(self) -> LlmUsageReportService:
        """What the AI costs, for the admin portal: aggregates of the usage
        ledger, priced like the daily cap prices them."""
        return LlmUsageReportService(
            self.llm_usage_repository,
            self.llm_budget,
            monthly_credits_usd=self.settings.llm_monthly_credits_usd,
            usd_per_eur=self.settings.llm_usd_per_eur,
            inference_geo=self.settings.anthropic_inference_geo,
        )

    def retention_dry_run_service(self) -> RetentionDryRunService:
        """Read-only report of what the data-retention job would do. Nothing
        here sends or erases; those collaborators are not wired on purpose."""
        return RetentionDryRunService(
            self.subscription_repository,
            self.owner_contact_lookup,
            self.developer_emails,
            self.account_consents_repository,
            AccountDataCounter(
                self.pet_profile_repository,
                self.clinical_event_repository,
                self.reminder_repository,
                self.dog_walk_repository,
            ),
            test_plan=self.subscription_test_plan,
            pending_deletions=self.account_deletion_repository.pending_owner_ids,
            paused=self.account_pause_repository.paused_owner_ids,
        )

    def register_device_service(self) -> RegisterDeviceService:
        return RegisterDeviceService(self.user_device_repository, self.owner_limits_lookup())

    def owner_limits_lookup(self) -> OwnerLimitsLookup:
        """What the owner's plan allows (None = no limits). On a lookup
        failure: with billing on, the last verified limits within the bounded
        tolerance, else no access (never "no limits"); without billing the
        legacy fail-open stays for development."""
        service = self.get_or_create_subscription_service()

        def lookup(owner_id: str, email: str | None) -> PlanLimits | None:
            try:
                result = service.execute(
                    GetOrCreateSubscriptionInput(owner_id=owner_id, email=email or "")
                )
                self.last_verified_access[owner_id] = (utc_now(), result.has_access, result.limits)
                return result.limits
            except Exception:  # noqa: BLE001 - bounded fallback below
                logger.exception("could not read the owner's plan limits")
                if not self.settings.billing_enabled:
                    return None
                cached = self.cached_access(owner_id)
                return cached[1] if cached is not None else NO_ACCESS_LIMITS

        return lookup

    def account_deletion_service(self) -> AccountDeletionService:
        return AccountDeletionService(
            self.account_deletion_repository,
            self._build_account_eraser(),
            self.settings.account_deletion_grace_days,
            self.account_consents_repository,
            self.pet_profile_repository,
            self.deletion_log_service,
        )

    def account_pause_service(self) -> AccountPauseService:
        return AccountPauseService(
            self.account_pause_repository,
            self.subscription_repository,
            self.settings.pause_max_months,
            self._build_account_eraser(),
            self.deletion_log_service,
        )

    def hidden_owner_ids(self) -> set[str]:
        """Sellers whose ads are hidden: asked to delete, or paused."""
        return self.account_deletion_repository.pending_owner_ids() | set(
            self.account_pause_repository.paused_owner_ids()
        )

    def _build_account_pause_repository(self) -> AccountPauseRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_pause_repository import (  # noqa: E501
                    SupabaseAccountPauseRepository,
                )

                return SupabaseAccountPauseRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryAccountPauseRepository()
                raise
        return InMemoryAccountPauseRepository()

    def _build_email_sender(self) -> EmailSender:
        """The one door for e-mail. Off (nothing leaves) unless
        EMAIL_SENDING_ENABLED is true AND a provider is configured; local and
        test runs never reach a real provider."""
        settings = self.settings
        if not settings.email_sending_enabled:
            return DisabledEmailSender()
        if settings.persistence_backend != "supabase":
            return InMemoryEmailSender()
        if not (settings.smtp_host and settings.email_from):
            return DisabledEmailSender()
        from packages.infrastructure.email.smtp_email_sender import SmtpEmailSender

        return SmtpEmailSender(
            settings.smtp_host,
            settings.smtp_port,
            settings.smtp_username,
            settings.smtp_password,
            settings.email_from,
            use_ssl=settings.smtp_use_ssl,
        )

    def _build_deletion_log_service(self) -> DeletionLogService:
        """The register of deletions: the table and a copy in a private bucket
        outside it (docs/security/03)."""
        reapply_days = self.settings.deletion_log_reapply_days
        proof_years = self.settings.deletion_log_proof_years
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_deletion_log import (
                    SupabaseDeletionLogRepository,
                    SupabaseStorageDeletionLogCopy,
                )

                client = build_supabase_client(self.settings)
                return DeletionLogService(
                    SupabaseDeletionLogRepository(client),
                    SupabaseStorageDeletionLogCopy(client, self.settings.deletion_log_bucket),
                    reapply_days,
                    proof_years,
                )
            except ModuleNotFoundError:
                if self.settings.environment == "production":
                    raise
        return DeletionLogService(
            InMemoryDeletionLogRepository(), InMemoryDeletionLogCopy(), reapply_days, proof_years
        )

    def _build_account_deletion_repository(self) -> AccountDeletionRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_deletion_repository import (  # noqa: E501
                    SupabaseAccountDeletionRepository,
                )

                return SupabaseAccountDeletionRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryAccountDeletionRepository()
                raise
        return InMemoryAccountDeletionRepository()

    def cached_access(self, owner_id: str) -> tuple[bool, PlanLimits | None] | None:
        entry = self.last_verified_access.get(owner_id)
        tolerance = timedelta(hours=min(self.settings.billing_verification_tolerance_hours, 1))
        if entry is None or utc_now() - entry[0] > tolerance:
            return None
        return entry[1], entry[2]

    def account_eraser(self) -> AccountEraser:
        return self._build_account_eraser()

    def age_review_admin_service(self) -> AgeReviewAdminService:
        return AgeReviewAdminService(
            self.account_age_repository,
            self.owner_contact_lookup,
            self._build_account_eraser(),
            self.settings.reporter_pseudonym_secret(),
            self.deletion_log_service,
        )

    def underage_review_dry_run_service(self) -> UnderageReviewDryRunService:
        return UnderageReviewDryRunService(self.account_age_repository)

    def age_gate_service(self) -> AgeGateService:
        return AgeGateService(self.account_age_repository)

    def _build_account_age_repository(self) -> AccountAgeRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_age_repository import (  # noqa: E501
                    SupabaseAccountAgeRepository,
                )

                return SupabaseAccountAgeRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryAccountAgeRepository()
                raise
        return InMemoryAccountAgeRepository()

    def delete_account_service(self) -> DeleteAccountService:
        return DeleteAccountService(self._build_account_eraser(), self.deletion_log_service)

    def export_account_data_service(self) -> ExportAccountDataService:
        return ExportAccountDataService(self._build_account_exporter())

    def _build_account_exporter(self) -> AccountExporter:
        # Same wiring (and same keys) as the eraser: the export must see
        # exactly what the deletion would remove.
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_account_exporter import (
                    SupabaseAccountExporter,
                )

                radar = self.radar_report_settings()
                return SupabaseAccountExporter(
                    build_supabase_client(self.settings),
                    media_bucket=self.settings.media_storage_bucket,
                    chat_reporter_secret=self.settings.reporter_pseudonym_secret(),
                    radar_pseudonym_key=radar.pseudonym_key if radar else None,
                )
            except ModuleNotFoundError:
                if self.settings.environment == "production":
                    raise
        return InMemoryAccountExporter(
            pet_profiles=self.pet_profile_repository,
            conversations=self.conversation_repository,
            reminders=self.reminder_repository,
            clinical_events=self.clinical_event_repository,
            pet_conditions=self.pet_condition_repository,
            account_consents=self.account_consents_repository,
            user_locations=self.user_location_repository,
            dog_walks=self.dog_walk_repository,
            marketplace_listings=self.marketplace_listing_repository,
            marketplace_messaging=self.marketplace_messaging_repository,
        )

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
        return SelectPlanService(
            self.subscription_repository,
            test_plan=self.subscription_test_plan,
            pets=self.pet_profile_repository,
        )

    def list_events_service(self) -> ListEventsService:
        return ListEventsService(self.event_catalog_repository())

    def event_catalog_repository(self) -> EventCatalogRepository:
        """One per process (the in-memory double keeps its rows)."""
        if self._event_catalog_repository is None:
            self._event_catalog_repository = self._build_event_catalog_repository()
        return self._event_catalog_repository

    def _build_event_catalog_repository(self) -> EventCatalogRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase import supabase_event_catalog
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )

                return supabase_event_catalog.SupabaseEventCatalogRepository(
                    build_supabase_client(self.settings)
                )
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryEventCatalogRepository()
                raise
        return InMemoryEventCatalogRepository()

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

    def travel_cards_service(self) -> ListTravelCardsService:
        """Around the world: the approved travel cards (files in the repository,
        no table: they are general content without personal data)."""
        return ListTravelCardsService(
            load_travel_cards(include_drafts=self.settings.travel_cards_include_drafts)
        )

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
            exotic_name_matching=self.settings.radar_exotic_name_matching,
        )

    def create_listing_service(self) -> CreateListingService:
        return CreateListingService(self.marketplace_listing_repository)

    def update_listing_service(self) -> UpdateListingService:
        return UpdateListingService(self.marketplace_listing_repository)

    def list_nearby_listings_service(self) -> ListNearbyListingsService:
        return ListNearbyListingsService(
            self.marketplace_listing_repository,
            hidden_owner_ids=self.hidden_owner_ids,
        )

    def marketplace_messaging_service(self) -> MarketplaceMessagingService:
        return MarketplaceMessagingService(
            self.marketplace_messaging_repository,
            self.marketplace_listing_repository,
            seller_can_answer=self.owner_can_write_on_marketplace,
        )

    def owner_can_write_on_marketplace(self, owner_id: str) -> bool:
        """Whether [owner_id]'s plan lets them write: the public test, a plan or an
        open trial. Read without creating anything, for someone other than the
        caller. The developer allowlist is matched by e-mail, which is not known
        here: a developer past the trial without a plan counts as without one."""
        if self.subscription_test_plan is not None:
            return True
        subscription = self.subscription_repository.get(owner_id)
        return subscription is not None and subscription.has_access(is_developer=False)

    def marketplace_messaging_moderation_service(self) -> MarketplaceMessagingModerationService:
        return MarketplaceMessagingModerationService(self.marketplace_messaging_repository)

    def report_listing_service(self) -> ReportListingService:
        return ReportListingService(
            self.marketplace_listing_repository, self.listing_report_repository
        )

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
            owner_limits=self.owner_limits_lookup(),
            account_age_repository=self.account_age_repository,
            photo_reading_enabled=self.photo_reading_enabled,
            recent_other_chats=self.settings.chat_answer_v2,
        )

    def chat_usage_maintenance_service(self) -> ChatUsageMaintenanceService:
        return ChatUsageMaintenanceService(
            self.llm_usage_repository,
            self.answer_cache_repository,
            retention=ChatRetentionService(
                self.conversation_repository,
                self.chat_attachment_repository,
                self.media_storage,
                retention_months=self.settings.chat_conversation_retention_months,
                orphan_days=self.settings.chat_orphan_attachment_retention_days,
            ),
        )

    def list_conversations_service(self) -> ListConversationsService:
        return ListConversationsService(self.conversation_repository)

    def delete_conversation_service(self) -> DeleteConversationService:
        return DeleteConversationService(self.conversation_repository)

    def edit_chat_message_service(self) -> EditChatMessageService:
        return EditChatMessageService(
            self.conversation_repository, self.send_chat_message_service()
        )

    def mark_not_helpful_service(self) -> MarkNotHelpfulService:
        return MarkNotHelpfulService(self.conversation_repository)

    def rename_conversation_service(self) -> RenameConversationService:
        return RenameConversationService(self.conversation_repository)

    def vet_summary_service(self) -> VetSummaryService:
        return VetSummaryService(
            self.conversation_repository,
            self.pet_profile_repository,
            self.llm_client,
            self.pii_anonymizer,
            budget=self.llm_budget,
            daily_limit=self.settings.chat_daily_summary_limit_per_user,
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
        return TranscribeAudioService(
            self.speech_to_text_provider,
            budget=self.llm_budget,
            daily_limit=self.settings.chat_daily_dictation_limit_per_user,
        )

    def upload_chat_attachment_service(self) -> UploadChatAttachmentService:
        return UploadChatAttachmentService(
            self.pet_profile_repository,
            self.chat_attachment_repository,
            self.media_storage,
            self.image_analyzer,
            pdf_reader=PypdfReader(),
            document_summarizer=DocumentSummarizer(self.llm_client, self.pii_anonymizer),
            pii_anonymizer=self.pii_anonymizer,
            budget=self.llm_budget,
            daily_limit=self.settings.chat_daily_vision_limit_per_user,
        )

    def _build_auth_provider(self) -> AuthProvider:
        # An account that declared an age under the minimum is closed: the
        # guard refuses it on every route (the age table is resolved lazily,
        # it is built after the provider).
        return AgeGuardedAuthProvider(
            self._build_inner_auth_provider(),
            lambda: self.account_age_repository,
            lambda: self.account_deletion_repository,
            lambda: self.account_pause_service(),
            lambda: self.account_consents_repository,
            lambda: self.settings.consent_enforcement_enabled,
        )

    def _build_inner_auth_provider(self) -> AuthProvider:
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

    def _build_llm_client(self) -> LLMClient:
        if self.settings.llm_provider == "anthropic":
            # Claude answers; the Groq chain is the automatic reserve when a
            # Groq key is configured (owner decision 2026-11-07).
            primary: LLMClient = AnthropicLLMClient(self.settings, availability=self.llm_budget)
            if groq_reserve_configured(self.settings):
                return ReserveLLMClient(
                    primary, GroqLLMClient(self.settings, availability=self.llm_budget)
                )
            return primary
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

    @property
    def photo_reading_enabled(self) -> bool:
        """False when photos are saved but never read (the chat says so)."""
        return not isinstance(self.image_analyzer, DisabledImageAnalyzer)

    def _build_image_analyzer(self) -> ImageAnalyzer:
        provider = self.settings.vision_provider
        if provider == "groq":
            if is_groq_production_model(self.settings.vision_model):
                return GroqImageAnalyzer(self.settings)
            # Empty, or a preview model outside Groq's data agreement
            # (docs/compliance/19): photos are saved, never read.
            logger.warning("VISION_MODEL is not a Groq production model: photo reading is off")
            return DisabledImageAnalyzer()
        if provider == "echo" and self.settings.environment != "production":
            # The local test double; never in production, where it would
            # hand the chat an invented description.
            return EchoImageAnalyzer()
        return DisabledImageAnalyzer()

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

    def submit_competence_claim_service(self) -> SubmitCompetenceClaimService | None:
        settings = self.radar_report_settings()
        if settings is None or not settings.reports_enabled:
            return None
        return SubmitCompetenceClaimService(
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

    def _build_marketplace_messaging_repository(self) -> MarketplaceMessagingRepository:
        if self.settings.persistence_backend == "supabase":
            try:
                from packages.infrastructure.persistence.supabase.client import (
                    build_supabase_client,
                )
                from packages.infrastructure.persistence.supabase.supabase_marketplace_messaging import (  # noqa: E501
                    SupabaseMarketplaceMessagingRepository,
                )

                return SupabaseMarketplaceMessagingRepository(build_supabase_client(self.settings))
            except ModuleNotFoundError:
                if self.settings.environment != "production":
                    return InMemoryMarketplaceMessagingRepository()
                raise
        return InMemoryMarketplaceMessagingRepository()

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
                overrides={
                    "husbandry_question": CuratedHusbandryEvidenceRetriever(),
                    # Repositioning (docs/product/11 §4, 2.4): behaviour and
                    # everyday questions read the curated awareness notes.
                    "behavior_question": CuratedAwarenessEvidenceRetriever(),
                    "everyday_question": CuratedAwarenessEvidenceRetriever(),
                },
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
                overrides={
                    "husbandry_question": CuratedHusbandryEvidenceRetriever(),
                    # Repositioning (docs/product/11 §4, 2.4): behaviour and
                    # everyday questions read the curated awareness notes.
                    "behavior_question": CuratedAwarenessEvidenceRetriever(),
                    "everyday_question": CuratedAwarenessEvidenceRetriever(),
                },
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
