"""Platform builders: sign-in, e-mail, LLM client and provider adapters (QK-20, verbatim)."""

import logging

from packages.bootstrap.container_state import ContainerState
from packages.bootstrap.settings_rules import groq_reserve_configured
from packages.core.application.ports.answer_cache_repository import AnswerCacheRepository
from packages.core.application.ports.auth_provider import AuthProvider
from packages.core.application.ports.email_sender import EmailSender
from packages.core.application.ports.evidence_retriever import EvidenceRetriever
from packages.core.application.ports.image_analyzer import ImageAnalyzer
from packages.core.application.ports.llm_client import LLMClient
from packages.core.application.ports.llm_usage_repository import LlmUsageRepository
from packages.core.application.ports.pii_anonymizer import PiiAnonymizer
from packages.core.application.ports.speech_to_text_provider import SpeechToTextProvider
from packages.infrastructure.auth.age_guarded_auth_provider import AgeGuardedAuthProvider
from packages.infrastructure.auth.bootstrap_auth_provider import BootstrapAuthProvider
from packages.infrastructure.email.in_memory_email_sender import (
    DisabledEmailSender,
    InMemoryEmailSender,
)
from packages.infrastructure.llm.providers.anthropic_llm_client import AnthropicLLMClient
from packages.infrastructure.llm.providers.echo_llm_client import EchoLLMClient
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
from packages.infrastructure.llm.retrieval.pubmed_evidence_retriever import PubMedEvidenceRetriever
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryAnswerCacheRepository,
    InMemoryLlmUsageRepository,
)
from packages.infrastructure.privacy.noop_pii_anonymizer import NoopPiiAnonymizer
from packages.infrastructure.privacy.rule_based_pii_anonymizer import RuleBasedPiiAnonymizer
from packages.infrastructure.speech.echo_speech_to_text_provider import EchoSpeechToTextProvider
from packages.infrastructure.speech.groq_speech_to_text_provider import GroqSpeechToTextProvider
from packages.infrastructure.vision.disabled_image_analyzer import DisabledImageAnalyzer
from packages.infrastructure.vision.echo_image_analyzer import EchoImageAnalyzer
from packages.infrastructure.vision.groq_image_analyzer import GroqImageAnalyzer
from packages.shared.config.groq_models import is_groq_production_model

logger = logging.getLogger("packages.bootstrap.container")


class PlatformWiring(ContainerState):
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
