import logging
from datetime import datetime, timedelta
from functools import lru_cache
from typing import TYPE_CHECKING

from packages.bootstrap.account_lifecycle_wiring import AccountLifecycleWiring
from packages.bootstrap.content_wiring import ContentWiring
from packages.bootstrap.marketplace_wiring import MarketplaceWiring
from packages.bootstrap.persistence_wiring import PersistenceWiring
from packages.bootstrap.platform_wiring import PlatformWiring
from packages.bootstrap.radar_wiring import RadarWiring
from packages.bootstrap.settings_rules import (  # noqa: F401 - moved there, re-exported (QK-20)
    _parse_plan_overrides,
    _resolve_subscription_test_plan,
    answer_models,
    groq_reserve_configured,
    resolve_memorial_pets_max,
)
from packages.core.application.ports.event_catalog_repository import EventCatalogRepository
from packages.core.application.ports.event_submission_repository import (
    EventSubmissionRepository,
)
from packages.core.application.ports.llm_client import LLMClient
from packages.core.application.ports.media_storage import MediaStorage
from packages.core.application.ports.owner_limits import OwnerLimitsLookup
from packages.core.application.ports.radar_places_source import RadarPlacesSource
from packages.core.application.ports.store_billing import (
    StoreEntitlementRepository,
    StoreVerifier,
)
from packages.core.application.services.account_data_counts import AccountDataCounter
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.consent_interpreter import ConsentInterpreter
from packages.core.application.services.create_pet_profile import CreatePetProfileService
from packages.core.application.services.create_reminder import CreateReminderService
from packages.core.application.services.delete_conversation import DeleteConversationService
from packages.core.application.services.document_summarizer import DocumentSummarizer
from packages.core.application.services.edit_chat_message import EditChatMessageService
from packages.core.application.services.evidence_query_normalizer import (
    EvidenceQueryNormalizer,
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
from packages.core.application.services.list_pet_profiles import ListPetProfilesService
from packages.core.application.services.list_reminders import ListRemindersService
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
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.plan_access_sync import PlanAccessSync
from packages.core.application.services.register_device import RegisterDeviceService
from packages.core.application.services.reminder_context_retriever import (
    ReminderContextRetriever,
)
from packages.core.application.services.rename_conversation import (
    RenameConversationService,
)
from packages.core.application.services.report_chat_response import ReportChatResponseService
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
from packages.core.application.services.store_billing import StoreBillingService
from packages.core.application.services.transcribe_audio import TranscribeAudioService
from packages.core.application.services.update_pet_profile import UpdatePetProfileService
from packages.core.application.services.upload_chat_attachment import UploadChatAttachmentService
from packages.core.application.services.urgency_classifier import UrgencyClassifier
from packages.core.application.services.vet_summary import VetSummaryService
from packages.core.domain.common.entity import utc_now
from packages.core.domain.subscription.limits import (
    NO_ACCESS_LIMITS,
    PlanLimits,
)
from packages.core.domain.subscription.store import ProductCatalog, Store
from packages.infrastructure.documents.pypdf_reader import PypdfReader
from packages.infrastructure.geocoding.nominatim_geocoder import NominatimGeocoder
from packages.infrastructure.persistence.in_memory_store_billing import (
    InMemoryStoreEntitlementRepository,
)
from packages.infrastructure.radar_places.overpass_places_source import (
    OverpassRadarPlacesSource,
)
from packages.shared.config.settings import Settings, get_settings

if TYPE_CHECKING:
    from packages.infrastructure.billing.apple_app_store import AppleSignedDataDecoder

logger = logging.getLogger(__name__)


class ApplicationContainer(
    RadarWiring,
    ContentWiring,
    MarketplaceWiring,
    AccountLifecycleWiring,
    PlatformWiring,
    PersistenceWiring,
):
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

    def cached_access(self, owner_id: str) -> tuple[bool, PlanLimits | None] | None:
        entry = self.last_verified_access.get(owner_id)
        tolerance = timedelta(hours=min(self.settings.billing_verification_tolerance_hours, 1))
        if entry is None or utc_now() - entry[0] > tolerance:
            return None
        return entry[1], entry[2]

    def select_plan_service(self) -> SelectPlanService:
        return SelectPlanService(
            self.subscription_repository,
            test_plan=self.subscription_test_plan,
            pets=self.pet_profile_repository,
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


@lru_cache(maxsize=1)
def get_container() -> ApplicationContainer:
    return ApplicationContainer(get_settings())


def reset_container() -> None:
    get_container.cache_clear()
