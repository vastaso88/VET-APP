from functools import lru_cache

from packages.core.application.ports.account_consents_repository import AccountConsentsRepository
from packages.core.application.ports.auth_provider import AuthProvider
from packages.core.application.ports.clinical_event_repository import ClinicalEventRepository
from packages.core.application.ports.conversation_repository import ConversationRepository
from packages.core.application.ports.evidence_retriever import EvidenceRetriever
from packages.core.application.ports.pet_profile_repository import PetProfileRepository
from packages.core.application.ports.pii_anonymizer import PiiAnonymizer
from packages.core.application.ports.reminder_repository import ReminderRepository
from packages.core.application.services.chat_orchestrator import ChatOrchestrator
from packages.core.application.services.consent_interpreter import ConsentInterpreter
from packages.core.application.services.create_pet_profile import CreatePetProfileService
from packages.core.application.services.create_reminder import CreateReminderService
from packages.core.application.services.delete_conversation import DeleteConversationService
from packages.core.application.services.get_account_consents import GetAccountConsentsService
from packages.core.application.services.get_pet_profile import GetPetProfileService
from packages.core.application.services.interview_planner import InterviewPlanner
from packages.core.application.services.list_conversations import ListConversationsService
from packages.core.application.services.list_pet_profiles import ListPetProfilesService
from packages.core.application.services.list_reminders import ListRemindersService
from packages.core.application.services.medical_record_context_retriever import (
    MedicalRecordContextRetriever,
)
from packages.core.application.services.safety_gate import SafetyGate
from packages.core.application.services.send_chat_message import SendChatMessageService
from packages.core.application.services.set_account_consent import SetAccountConsentService
from packages.core.application.services.set_medical_record_consent import (
    SetMedicalRecordConsentService,
)
from packages.core.application.services.situation_model_builder import SituationModelBuilder
from packages.core.application.services.update_pet_profile import UpdatePetProfileService
from packages.infrastructure.auth.bootstrap_auth_provider import BootstrapAuthProvider
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
from packages.infrastructure.llm.providers.groq_llm_client import GroqLLMClient
from packages.infrastructure.llm.retrieval.crossref_evidence_retriever import (
    CrossrefEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.europe_pmc_evidence_retriever import (
    EuropePmcEvidenceRetriever,
)
from packages.infrastructure.llm.retrieval.in_memory_evidence_retriever import (
    InMemoryEvidenceRetriever,
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
    InMemoryClinicalEventRepository,
    InMemoryConversationRepository,
    InMemoryPetProfileRepository,
    InMemoryReminderRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
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
        self.evidence_retriever = self._build_evidence_retriever()
        self.pii_anonymizer = self._build_pii_anonymizer()
        self.clinical_event_repository = self._build_clinical_event_repository()
        self.account_consents_repository = self._build_account_consents_repository()
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

    def send_chat_message_service(self) -> SendChatMessageService:
        return SendChatMessageService(
            self.conversation_repository,
            self.chat_orchestrator,
            self.pet_profile_repository,
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

    def _build_evidence_retriever(self) -> EvidenceRetriever:
        if self.settings.evidence_backend == "europe_pmc":
            return EuropePmcEvidenceRetriever()
        if self.settings.evidence_backend == "scientific_multi":
            # Spec v3 §20: PubMed, Europe PMC, Crossref and OpenAlex are
            # complementary sources, not alternatives to pick one of.
            return MultiSourceEvidenceRetriever(
                [
                    EuropePmcEvidenceRetriever(),
                    PubMedEvidenceRetriever(),
                    CrossrefEvidenceRetriever(),
                    OpenAlexEvidenceRetriever(),
                ]
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
